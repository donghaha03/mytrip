import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/country.dart';
import '../models/trip.dart';
import '../models/receipt_item.dart';

/// 원격 저장소. TripStore 가 로그인한 사용자 기준으로 하나 만들어 붙인다.
/// (로컬 임시 모드에서는 아예 안 쓰고 메모리만 쓴다)
abstract class TripRepository {
  /// 여행 목록 실시간 스트림. expenses 는 비어 있다 — [watchExpenses] 로 따로 받는다.
  Stream<List<Trip>> watchTrips();
  Stream<List<Expense>> watchExpenses(String tripId);

  Future<void> saveTrip(Trip trip);
  Future<void> renameTrip(String tripId, String name);

  /// 이름·기간·예산 (지출과 생성 시각은 그대로)
  Future<void> updateTrip(Trip trip);
  Future<void> deleteTrip(String tripId);
  Future<void> saveExpense(String tripId, Expense expense);
  Future<void> deleteExpense(String tripId, String expenseId);
}

/// Firestore 구조:
///
///   users/{uid}/trips/{tripId}                    이름·국가·기간·예산
///   users/{uid}/trips/{tripId}/records/{id}       지출 한 건
///
/// 지출의 date 는 날짜가 아니라 시분초까지 있는 Timestamp 로 저장한다 —
/// 같은 날 여러 건을 기록해도 순서가 안 섞인다.
class FirestoreTripRepository implements TripRepository {
  FirestoreTripRepository({required this.uid, FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _trips =>
      _db.collection('users').doc(uid).collection('trips');

  CollectionReference<Map<String, dynamic>> _records(String tripId) =>
      _trips.doc(tripId).collection('records');

  @override
  Stream<List<Trip>> watchTrips() => _trips
      .orderBy('start')
      .snapshots()
      .map((s) => s.docs.map(_tripFrom).nonNulls.toList());

  @override
  Stream<List<Expense>> watchExpenses(String tripId) => _records(tripId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .where((d) => d.data()['hidden'] != true)
            .map(_expenseFrom)
            .toList(),
      );

  @override
  Future<void> saveTrip(Trip t) => _trips.doc(t.id).set({
    'name': t.name,
    'currency': t.country.currency,
    'countryCode': t.country.code,
    'start': Timestamp.fromDate(t.start),
    'end': Timestamp.fromDate(t.end),
    'budgetKrw': t.budgetKrw,
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> renameTrip(String tripId, String name) =>
      _trips.doc(tripId).update({'name': name});

  // set() 이 아니라 update() — createdAt 을 덮어쓰지 않으려고
  @override
  Future<void> updateTrip(Trip t) => _trips.doc(t.id).update({
    'name': t.name,
    'start': Timestamp.fromDate(t.start),
    'end': Timestamp.fromDate(t.end),
    'budgetKrw': t.budgetKrw,
  });

  /// 문서를 지워도 하위 컬렉션은 안 지워지는 게 Firestore 규칙이라
  /// records 를 먼저 같이 지운다.
  @override
  Future<void> deleteTrip(String tripId) async {
    final batch = _db.batch();
    final records = await _records(tripId).get();
    for (final r in records.docs) {
      batch.delete(r.reference);
    }
    batch.delete(_trips.doc(tripId));
    await batch.commit();
  }

  @override
  Future<void> saveExpense(String tripId, Expense e) =>
      _records(tripId).doc(e.id).set({
        'icon': e.icon,
        'place': e.place,
        'amount': e.amount,
        'category': e.category,
        'paymentMethod': e.paymentMethod?.name,
        'isTaxFree': e.isTaxFree,
        'date': Timestamp.fromDate(e.date),
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
      }, SetOptions(merge: true));

  @override
  Future<void> deleteExpense(String tripId, String expenseId) async {
    final ref = _records(tripId).doc(expenseId);
    final record = await ref.get();
    if (record.data()?['source'] != null) {
      await ref.set({'hidden': true}, SetOptions(merge: true));
    } else {
      await ref.delete();
    }
  }

  /// 통화 코드를 모르는 문서(앱에서 국가를 뺀 경우 등)는 건너뛴다.
  static Trip? _tripFrom(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final country =
        countryByIso(m['countryCode'] as String? ?? '') ??
        countryByCode(m['currency'] as String? ?? '');
    if (country == null) return null;
    return Trip(
      id: d.id,
      name: m['name'] as String? ?? '',
      country: country,
      start: (m['start'] as Timestamp).toDate(),
      end: (m['end'] as Timestamp).toDate(),
      budgetKrw: (m['budgetKrw'] as num).toInt(),
    );
  }

  static Expense _expenseFrom(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Expense(
      id: d.id,
      icon: m['icon'] as String? ?? '💸',
      place: m['place'] as String? ?? '',
      // 1200.0 을 넣어도 웹에서는 int 로 돌아올 수 있다
      amount: (m['amount'] as num).toDouble(),
      category: m['category'] as String? ?? '기타',
      paymentMethod: PaymentMethod.values
          .where((method) => method.name == m['paymentMethod'])
          .firstOrNull,
      isTaxFree: m['isTaxFree'] == true,
      date: (m['date'] as Timestamp).toDate(),
      currency: m['currency'] as String?,
      memo: m['memo'] as String? ?? '',
      recordedQuote: (m['recordedQuote'] as num?)?.toInt(),
      source: m['source'] as String?,
      status:
          ExpenseStatus.values
              .where((s) => s.name == m['status'])
              .firstOrNull ??
          ExpenseStatus.approved,
      originalAmount: (m['originalAmount'] as num?)?.toDouble(),
      receiptFingerprint: m['receiptFingerprint'] as String?,
      receiptAdjustments: ReceiptAdjustments.fromJson(m['receiptAdjustments']),
      receiptTaxes:
          (m['receiptTaxes'] is List ? m['receiptTaxes'] as List : const [])
              .map(ReceiptTax.fromJson)
              .nonNulls
              .toList(),
      receiptItems:
          (m['receiptItems'] is List ? m['receiptItems'] as List : const [])
              .map(ReceiptItem.fromJson)
              .nonNulls
              .toList(),
    );
  }
}
