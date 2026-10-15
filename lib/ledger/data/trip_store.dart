import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/api.dart' as api;
import '../models/country.dart';
import '../models/trip.dart';

/// 장부 한 화면의 상태. 저장은 팀 API만 사용한다.
class TripStore extends ChangeNotifier {
  TripStore({
    required this.tripId,
    Stream<api.Trip?>? tripStream,
    Stream<List<Expense>>? expenseStream,
  }) {
    _owner = tripStream == null ? api.AuthApi.uid : null;
    _tripSub = (tripStream ?? api.TripApi.watch(tripId)).listen(
      _receiveTrip,
      onError: _failed,
    );
    _expensesSub = (expenseStream ?? api.ExpenseApi.watchAll(tripId)).listen((
      list,
    ) {
      if (_disposed) return;
      _expenses = list;
      trip?.expenses
        ?..clear()
        ..addAll(list);
      _expensesReady = true;
      notifyListeners();
    }, onError: _failed);
  }

  final String tripId;
  String? _owner;
  late final StreamSubscription<api.Trip?> _tripSub;
  late final StreamSubscription<List<Expense>> _expensesSub;
  List<Expense> _expenses = [];
  bool _tripReady = false, _expensesReady = false, _disposed = false;
  Trip? trip;
  Object? error;
  bool get isLoading => !_tripReady || (trip != null && !_expensesReady);

  void _failed(Object e) {
    if (_disposed) return;
    error = e;
    notifyListeners();
  }

  void _receiveTrip(api.Trip? value) {
    if (_disposed) return;
    _tripReady = true;
    if (value == null) {
      trip = null;
    } else {
      final country = countryByCode(value.currency);
      if (country == null) {
        _failed(const api.ApiException('지원하지 않는 여행 통화예요'));
        return;
      }
      trip ??= Trip(
        id: value.id,
        name: value.name,
        country: country,
        start: value.start,
        end: value.end,
        budgetKrw: value.budget,
        expenses: [..._expenses],
      );
      trip!
        ..name = value.name
        ..country = country
        ..start = value.start
        ..end = value.end
        ..budgetKrw = value.budget;
    }
    notifyListeners();
  }

  void _checkActive() {
    if (_disposed ||
        trip == null ||
        error != null ||
        (_owner != null && api.AuthApi.user?.uid != _owner)) {
      throw const api.ApiException('여행 정보를 다시 열어주세요');
    }
  }

  Future<void> saveExpense(String id, Expense expense) async {
    _checkActive();
    if (id != tripId) throw const api.ApiException('여행 정보가 변경됐어요');
    if (expense.id.isEmpty) {
      await api.ExpenseApi.add(
        tripId,
        category: expense.category,
        place: expense.place,
        amount: expense.amount,
        currency: expense.currency,
        date: expense.date,
        icon: expense.icon,
        paymentMethod: expense.paymentMethod,
        isTaxFree: expense.isTaxFree,
        memo: expense.memo,
        recordedQuote: expense.recordedQuote,
        source: expense.source,
        status: expense.status,
        originalAmount: expense.originalAmount,
        receiptFingerprint: expense.receiptFingerprint,
        receiptItems: expense.receiptItems,
        receiptTaxes: expense.receiptTaxes,
        receiptAdjustments: expense.receiptAdjustments,
      );
      return;
    }
    await api.ExpenseApi.update(tripId, expense);
    _checkActive();
    final index = trip!.expenses.indexWhere((e) => e.id == expense.id);
    if (index < 0) {
      trip!.expenses.add(expense);
    } else {
      trip!.expenses[index] = expense;
    }
    notifyListeners();
  }

  Future<void> deleteExpense(String id, String expenseId) async {
    _checkActive();
    if (id != tripId) throw const api.ApiException('여행 정보가 변경됐어요');
    await api.ExpenseApi.delete(tripId, expenseId);
    _checkActive();
    trip!.expenses.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  Future<void> update({
    required String name,
    required DateTime start,
    required DateTime end,
    required int budgetKrw,
  }) async {
    _checkActive();
    if (name.trim().isEmpty || end.isBefore(start) || budgetKrw < 0) {
      throw const api.ApiException('여행 이름·기간·예산을 확인해주세요');
    }
    await api.TripApi.update(
      api.Trip(
        id: tripId,
        name: name.trim(),
        budget: budgetKrw,
        currency: trip!.country.currency,
        start: start,
        end: end,
      ),
    );
  }

  Future<void> remove() async {
    _checkActive();
    await api.TripApi.delete(tripId);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_tripSub.cancel());
    unawaited(_expensesSub.cancel());
    super.dispose();
  }
}
