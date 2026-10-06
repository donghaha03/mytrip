import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/country.dart';
import '../models/trip.dart';
import '../models/receipt_item.dart';
import 'trip_repository.dart';

bool _invalidDates(DateTime start, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).isBefore(DateTime.utc(start.year, start.month, start.day));

/// 화면이 보는 여행 목록.
///
/// 화면 쪽은 모드를 몰라도 된다 — add/remove/rename/addExpense 를 부르고
/// trips 를 읽기만 하면 된다.
///
///  - 웹 미리보기: 메모리 샘플. 모바일 기본 실행: 기기 저장소.
///  - Firebase 모드: [connect] 로 Firestore 에 붙는다. 쓰기는 메모리에 먼저
///    반영하고(화면이 바로 바뀌게) Firestore 로 보낸다. 다른 기기에서 바뀐
///    내용은 스냅샷으로 들어와 합쳐진다.
class TripStore extends ChangeNotifier {
  final List<Trip> _trips = [];

  TripRepository? _repo;
  StreamSubscription<List<Trip>>? _tripsSub;
  final Map<String, StreamSubscription<List<Expense>>> _expenseSubs = {};
  bool _loading = false;
  bool _remote = false;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isEmpty => _trips.isEmpty;

  /// Firestore 에서 첫 스냅샷을 기다리는 중. 이때 빈 화면(00)을 띄우면
  /// 여행이 있는 사용자한테도 "아직 떠날 준비가..." 가 번쩍 보인다.
  bool get isLoading => _loading;
  bool get isRemote => _remote;

  Trip? byId(String id) {
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  void add(Trip trip) {
    if (_invalidDates(trip.start, trip.end)) {
      throw ArgumentError('종료일은 시작일보다 빠를 수 없어요');
    }
    _trips.add(trip);
    notifyListeners();
    _push(_repo?.saveTrip(trip));
  }

  void remove(String id) {
    _trips.removeWhere((t) => t.id == id);
    _expenseSubs.remove(id)?.cancel();
    notifyListeners();
    _push(_repo?.deleteTrip(id));
  }

  void rename(String id, String newName) {
    final trip = byId(id);
    if (trip == null) return;
    trip.name = newName;
    notifyListeners();
    _push(_repo?.renameTrip(id, newName));
  }

  /// 06 여행 편집에서 이름·기간·예산을 한 번에 바꾼다. 준 것만 바뀐다.
  void update(
    String id, {
    String? name,
    DateTime? start,
    DateTime? end,
    int? budgetKrw,
  }) {
    final trip = byId(id);
    if (trip == null) return;
    if (_invalidDates(start ?? trip.start, end ?? trip.end)) {
      throw ArgumentError('종료일은 시작일보다 빠를 수 없어요');
    }
    if (name != null) trip.name = name;
    if (start != null) trip.start = start;
    if (end != null) trip.end = end;
    if (budgetKrw != null) trip.budgetKrw = budgetKrw;
    notifyListeners();
    _push(_repo?.updateTrip(trip));
  }

  Future<void> addExpense(String tripId, Expense expense) =>
      saveExpense(tripId, expense);

  /// 같은 ID면 수정한다. 원격 저장 실패 시 기존 목록과 입력을 유지한다.
  Future<void> saveExpense(String tripId, Expense expense) async {
    final trip = byId(tripId);
    if (trip == null) throw StateError('여행을 찾을 수 없어요');
    if (expense.id.isEmpty ||
        expense.place.trim().isEmpty ||
        !expense.amount.isFinite ||
        expense.amount < 0 ||
        (expense.status.countsAsSpending &&
            (expense.isImported
                ? expense.amount <= 0
                : expense.amount.truncate() <= 0)) ||
        expense.memo.length > 300 ||
        (expense.receiptAdjustments != null &&
            ReceiptAdjustments.fromJson(expense.receiptAdjustments!.toJson()) ==
                null) ||
        expense.receiptTaxes.length > 10 ||
        expense.receiptTaxes.any(
          (tax) =>
              ReceiptTax.fromJson(tax.toJson()) == null ||
              countryByCode(tax.currency) == null,
        ) ||
        expense.receiptItems.length > 100 ||
        expense.receiptItems.any(
          (item) => ReceiptItem.fromJson(item.toJson()) == null,
        ) ||
        (expense.currency != null &&
            countryByCode(expense.currency!) == null)) {
      throw ArgumentError('사용처와 금액을 확인해주세요');
    }
    final repo = _repo;
    await repo?.saveExpense(tripId, expense);
    if (!identical(byId(tripId), trip) || !identical(repo, _repo)) {
      throw StateError('여행 정보가 변경됐어요');
    }
    final index = trip.expenses.indexWhere((e) => e.id == expense.id);
    if (index < 0) {
      trip.expenses.add(expense);
    } else {
      trip.expenses[index] = expense;
    }
    notifyListeners();
  }

  Future<void> deleteExpense(String tripId, String expenseId) async {
    final trip = byId(tripId);
    if (trip == null) throw StateError('여행을 찾을 수 없어요');
    final repo = _repo;
    await repo?.deleteExpense(tripId, expenseId);
    if (!identical(byId(tripId), trip) || !identical(repo, _repo)) {
      throw StateError('여행 정보가 변경됐어요');
    }
    trip.expenses.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 원격 저장소 연결
  // -------------------------------------------------------------------------

  /// 로그인한 사용자의 저장소에 붙는다. null 이면 떼고 목록을 비운다 (로그아웃).
  void connect(TripRepository? repo, {bool remote = true}) {
    _tripsSub?.cancel();
    _tripsSub = null;
    for (final s in _expenseSubs.values) {
      s.cancel();
    }
    _expenseSubs.clear();
    _trips.clear();

    _repo = repo;
    _remote = repo != null && remote;
    _loading = repo != null;
    notifyListeners();

    _tripsSub = repo?.watchTrips().listen(
      _mergeTrips,
      onError: (Object e) {
        debugPrint('[TripStore] 여행 목록 구독 실패: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  /// 스냅샷을 기존 객체에 "덮어쓰지 않고 합친다".
  ///
  /// 03 메인 같은 화면은 Trip 객체를 들고 있어서, 새 객체로 갈아 끼우면
  /// 열려 있는 화면이 옛날 값을 계속 보여준다. id 가 같으면 필드만 갱신한다.
  void _mergeTrips(List<Trip> fresh) {
    final freshIds = {for (final t in fresh) t.id};

    _trips.removeWhere((t) => !freshIds.contains(t.id));
    for (final id in _expenseSubs.keys.toList()) {
      if (!freshIds.contains(id)) _expenseSubs.remove(id)?.cancel();
    }

    for (final f in fresh) {
      final existing = byId(f.id);
      if (existing == null) {
        _trips.add(f);
      } else {
        existing
          ..name = f.name
          ..country = f.country
          ..start = f.start
          ..end = f.end
          ..budgetKrw = f.budgetKrw;
      }
      _expenseSubs[f.id] ??= _repo!.watchExpenses(f.id).listen((list) {
        final t = byId(f.id);
        if (t == null) return;
        t.expenses
          ..clear()
          ..addAll(list);
        notifyListeners();
      });
    }

    // 서버 정렬(시작일 순)을 따른다
    final order = {for (var i = 0; i < fresh.length; i++) fresh[i].id: i};
    _trips.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));

    _loading = false;
    notifyListeners();
  }

  /// 원격 쓰기. 실패해도 화면은 이미 바뀐 상태라 로그만 남긴다.
  /// (권한 오류가 나면 firestore.rules 를 확인할 것)
  void _push(Future<void>? write) {
    write?.catchError((Object e) {
      debugPrint('[TripStore] Firestore 쓰기 실패: $e');
    });
  }

  /// 00 빈 화면 -> 01 리스트 화면 전환을 눈으로 확인하려면
  /// main.dart 에서 이 함수를 호출해 목업을 채운다.
  void seedMockTrips() {
    if (_trips.isNotEmpty) return;
    final now = DateTime.now();

    final japan = kPrimaryCountries.firstWhere((c) => c.currency == 'JPY');
    final thailand = kPrimaryCountries.firstWhere((c) => c.currency == 'THB');
    final usa = kPrimaryCountries.firstWhere((c) => c.currency == 'USD');

    _trips.addAll([
      // 이미 지난 여행 -> "여행완료" 도장이 찍힌다
      Trip(
        id: 't1',
        name: '미국 여행',
        country: usa,
        start: DateTime(now.year, now.month - 2, 1),
        end: DateTime(now.year, now.month - 2, 10),
        budgetKrw: 2400000,
      ),
      Trip(
        id: 't2',
        name: '일본 여행',
        country: japan,
        start: now.add(const Duration(days: 11)),
        end: now.add(const Duration(days: 15)),
        budgetKrw: 1200000,
        expenses: [
          Expense(
            id: 'e1',
            icon: '🍜',
            category: '식비',
            place: '이치란 라멘',
            paymentMethod: PaymentMethod.cash,
            amount: 1200,
            date: now.subtract(const Duration(hours: 3)),
          ),
          Expense(
            id: 'e2',
            icon: '🚃',
            category: '교통',
            place: 'JR 패스',
            paymentMethod: PaymentMethod.card,
            amount: 3500,
            date: now.subtract(const Duration(days: 1, hours: 2)),
          ),
          Expense(
            id: 'e3',
            icon: '🛍',
            category: '쇼핑',
            place: '돈키호테',
            paymentMethod: PaymentMethod.card,
            amount: 2800,
            date: now.subtract(const Duration(days: 1, hours: 6)),
          ),
          Expense(
            id: 'e4',
            icon: '🏨',
            category: '숙박',
            place: '신주쿠 호텔',
            paymentMethod: PaymentMethod.card,
            amount: 40600,
            date: now.subtract(const Duration(days: 2)),
          ),
        ],
      ),
      // 이름을 직접 바꾼 여행 (편집 기능 예시)
      Trip(
        id: 't3',
        name: '가족 여행',
        country: thailand,
        start: now.add(const Duration(days: 51)),
        end: now.add(const Duration(days: 56)),
        budgetKrw: 1800000,
      ),
    ]);
  }
}

/// 앱 전역에서 쓰는 단일 인스턴스.
/// provider/riverpod 을 도입하면 이 전역 변수를 걷어내면 된다.
final tripStore = TripStore();
