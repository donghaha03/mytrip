import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/country.dart';
import '../models/receipt_item.dart';
import '../models/trip.dart';
import 'trip_repository.dart';

/// Device-only storage. No account, receipt photos or remote sync.
class DeviceTripRepository implements TripRepository {
  DeviceTripRepository._(this._prefs, this._data);
  static const storageKey = 'mytrip.device_trips.v1';
  final SharedPreferences _prefs;
  Map<String, dynamic> _data;
  final _changes = StreamController<void>.broadcast();
  Future<void> _writes = Future.value();

  static Future<DeviceTripRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final data = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    // Validate before subscribing or writing; never replace unreadable records.
    for (final entry in data.entries) {
      _trip(entry.key, entry.value as Map<String, dynamic>);
      _expenses(entry.value as Map<String, dynamic>);
    }
    return DeviceTripRepository._(prefs, data);
  }

  @override
  Stream<List<Trip>> watchTrips() async* {
    List<Trip> snapshot() => [
      for (final entry in _data.entries)
        _trip(entry.key, entry.value as Map<String, dynamic>),
    ]..sort((a, b) => a.start.compareTo(b.start));
    yield snapshot();
    yield* _changes.stream.map((_) => snapshot());
  }

  @override
  Stream<List<Expense>> watchExpenses(String tripId) async* {
    List<Expense> snapshot() => _data[tripId] == null
        ? []
        : _expenses(_data[tripId] as Map<String, dynamic>);
    yield snapshot();
    yield* _changes.stream.map((_) => snapshot());
  }

  Future<void> _write(void Function(Map<String, dynamic>) change) {
    final write = _writes.then((_) async {
      final next = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
      change(next);
      if (!await _prefs.setString(storageKey, jsonEncode(next))) {
        throw StateError('기기에 저장하지 못했어요');
      }
      _data = next;
      _changes.add(null);
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<void> saveTrip(Trip t) => _write((data) {
    data[t.id] = {
      'name': t.name,
      'countryCode': t.country.code,
      'start': t.start.toIso8601String(),
      'end': t.end.toIso8601String(),
      'budgetKrw': t.budgetKrw,
      'expenses': data[t.id]?['expenses'] ?? <String, dynamic>{},
    };
  });
  @override
  Future<void> updateTrip(Trip trip) => saveTrip(trip);
  @override
  Future<void> renameTrip(String id, String name) => _write((data) {
    data[id]['name'] = name;
  });
  @override
  Future<void> deleteTrip(String id) => _write((data) => data.remove(id));
  @override
  Future<void> saveExpense(String tripId, Expense e) => _write((data) {
    data[tripId]['expenses'][e.id] = {
      'id': e.id,
      'icon': e.icon,
      'place': e.place,
      'amount': e.amount,
      'date': e.date.toIso8601String(),
      'category': e.category,
      'paymentMethod': e.paymentMethod?.name,
      'isTaxFree': e.isTaxFree,
      'currency': e.currency,
      'memo': e.memo,
      'recordedQuote': e.recordedQuote,
      'source': e.source,
      'status': e.status.name,
      'originalAmount': e.originalAmount,
      'receiptFingerprint': e.receiptFingerprint,
      'receiptItems': e.receiptItems.map((item) => item.toJson()).toList(),
      'receiptTaxes': e.receiptTaxes.map((tax) => tax.toJson()).toList(),
      'receiptAdjustments': e.receiptAdjustments?.toJson(),
    };
  });
  @override
  Future<void> deleteExpense(String tripId, String expenseId) => _write((data) {
    data[tripId]['expenses'].remove(expenseId);
  });

  static Trip _trip(String id, Map<String, dynamic> m) => Trip(
    id: id,
    name: m['name'] as String,
    country:
        countryByIso(m['countryCode'] as String) ??
        (throw const FormatException('Unknown country')),
    start: DateTime.parse(m['start'] as String),
    end: DateTime.parse(m['end'] as String),
    budgetKrw: (m['budgetKrw'] as num).toInt(),
  );
  static List<Expense> _expenses(Map<String, dynamic> trip) => [
    for (final m in (trip['expenses'] as Map<String, dynamic>).values)
      Expense(
        id: m['id'] as String,
        icon: m['icon'] as String,
        place: m['place'] as String,
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        category: m['category'] as String,
        paymentMethod: PaymentMethod.values
            .where((v) => v.name == m['paymentMethod'])
            .firstOrNull,
        isTaxFree: m['isTaxFree'] == true,
        currency: m['currency'] as String?,
        memo: m['memo'] as String,
        recordedQuote: (m['recordedQuote'] as num?)?.toInt(),
        source: m['source'] as String?,
        status: ExpenseStatus.values.byName(m['status'] as String),
        originalAmount: (m['originalAmount'] as num?)?.toDouble(),
        receiptFingerprint: m['receiptFingerprint'] as String?,
        receiptAdjustments: m['receiptAdjustments'] == null
            ? null
            : ReceiptAdjustments.fromJson(m['receiptAdjustments']) ??
                  (throw const FormatException('Invalid receipt adjustments')),
        receiptTaxes: (m['receiptTaxes'] as List? ?? const [])
            .map(
              (tax) =>
                  ReceiptTax.fromJson(tax) ??
                  (throw const FormatException('Invalid receipt tax')),
            )
            .toList(),
        receiptItems: (m['receiptItems'] as List)
            .map(
              (item) =>
                  ReceiptItem.fromJson(item) ??
                  (throw const FormatException('Invalid receipt item')),
            )
            .toList(),
      ),
  ];

  Future<void> close() async {
    await _writes;
    await _changes.close();
  }
}
