import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart';
import 'package:tripapp/trip_home/data/trip_repository.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/screens/expense_form_screen.dart';
import 'package:tripapp/trip_home/screens/ledger_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';
import 'package:tripapp/trip_home/widgets/recent_expenses_card.dart';
import 'package:tripapp/trip_home/widgets/today_budget_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);

Future<void> _loadRates({double yen = 8.624175011418408}) async {
  final now = DateTime.now().toUtc();
  final client = MockClient(
    (_) async => http.Response(
      jsonEncode({
        'result': 'success',
        'base_code': 'KRW',
        'rate_date': now.toIso8601String().substring(0, 10),
        'fetched_at': now.toIso8601String(),
        'rates': {
          for (final c in [...kPrimaryCountries, ...kMoreCountries])
            c.currency: c.currency == 'JPY'
                ? 1 / yen
                : c.unitAmount / c.krwPerUnit,
        },
      }),
      200,
    ),
  );
  try {
    await RateApi.load(force: true, client: client);
  } finally {
    client.close();
  }
}

Trip _trip() => Trip(
  id: 'ledger',
  name: '일본 여행',
  country: countryByCode('JPY')!,
  start: DateTime(2026, 10, 1),
  end: DateTime(2026, 10, 5),
  budgetKrw: 100000,
  expenses: [
    for (var i = 1; i <= 3; i++)
      Expense(
        id: 'e$i',
        icon: '🍜',
        place: '상점$i',
        amount: 1501,
        category: '식비',
        date: DateTime(2026, 10, 1, 10, i),
      ),
  ],
);

/// 오류가 UI와 원래 데이터에 그대로 전달되는지 확인하는 저장소.
class _FailingRepository extends FirestoreTripRepository {
  _FailingRepository(FakeFirebaseFirestore db) : super(uid: 'test', db: db);
  @override
  Future<void> saveExpense(String tripId, Expense expense) async =>
      throw StateError('쓰기 실패');
  @override
  Future<void> deleteExpense(String tripId, String expenseId) async =>
      throw StateError('삭제 실패');
}

void main() {
  late Trip trip;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RateApi.reset();
    await _loadRates();
    tripStore.connect(null);
    trip = _trip();
    tripStore.add(trip);
  });
  tearDown(() => tripStore.connect(null));

  test('항목·날짜·홈·오늘 예산의 합계와 환율 갱신이 일치한다', () async {
    expect(trip.spentKrw, 38814); // 12,938원씩 더한다. 통째 환산(38,815원)과 다름.
    expect(dailySpending(trip, DateTime(2026, 10, 1)).last.krw, trip.spentKrw);
    expect(
      todayBudget(trip, DateTime(2026, 10, 1)).spentTodayKrw,
      trip.spentKrw,
    );
    await _loadRates(yen: 9.501);
    expect(trip.spentKrw, 42777); // 100엔 = 950원, 각 14,259원.
    expect(trip.remainKrw, 57223);
  });

  testWidgets('추가하면 홈과 장부에 같은 기록이 반영되고 소수점은 버린다', (tester) async {
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: trip)));
    await tester.tap(find.text('지출 기록'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '1000.9',
    );
    await tester.enterText(find.byKey(const ValueKey('expense-place')), '편의점');
    await tester.pump();
    expect(find.text('원화 환산 8,620원'), findsOneWidget);
    await tester.ensureVisible(find.text('🛍 쇼핑'));
    await tester.tap(find.text('🛍 쇼핑'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(TripHomeScreen), findsOneWidget);
    expect(trip.expenses.length, 4);
    expect(trip.expenses.last.amount, 1000);
    expect(trip.expenses.last.category, '쇼핑');
    expect(trip.spentKrw, 47434);
    expect(find.text('47,434원'), findsOneWidget);
    await tester.tap(find.text('장부 보기'));
    await tester.pumpAndSettle();
    expect(find.text('편의점'), findsOneWidget);
    expect(find.text('47,434원'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('수정은 ID·날짜를 유지하며 삭제 취소와 확인을 구분한다', (tester) async {
    final original = trip.expenses.first;
    await tester.pumpWidget(_wrap(LedgerScreen(trip: trip)));
    await tester.ensureVisible(find.text('상점1'));
    await tester.tap(find.text('상점1'));
    await tester.pumpAndSettle();
    expect(find.text('지출 수정'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '2000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-place')),
      '수정한 상점',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(trip.expenses.length, 3);
    final updated = trip.expenses.firstWhere((e) => e.id == original.id);
    expect(updated.date, original.date);
    expect(updated.amount, 2000);
    expect(trip.spentKrw, 43116);
    await tester.ensureVisible(find.text('수정한 상점'));
    await tester.tap(find.text('수정한 상점'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('지출 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(trip.expenses.length, 3);
    await tester.tap(find.byTooltip('지출 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsOneWidget);
    expect(trip.expenses.length, 2);
    expect(trip.spentKrw, 25876);
    expect(find.text('수정한 상점'), findsNothing);
  });

  testWidgets('빈 값·0원은 저장되지 않고 환율 없으면 저장할 수 없다', (tester) async {
    await tester.pumpWidget(_wrap(ExpenseFormScreen(trip: trip)));
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '0');
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.text('금액은 1 이상 입력해주세요'), findsOneWidget);
    expect(find.text('사용처를 입력해주세요'), findsOneWidget);
    expect(trip.expenses.length, 3);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '');
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '-100',
    );
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.text('금액은 1 이상 입력해주세요'), findsOneWidget);
    expect(trip.expenses.length, 3);
    RateApi.reset();
    RateApi.changes.value++;
    await tester.pump();
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '저장'),
    );
    expect(save.onPressed, isNull);
    expect(find.text('환율을 불러오면 기록할 수 있어요'), findsOneWidget);
  });

  testWidgets('날짜는 하루만 선택하며 시각은 유지한다', (tester) async {
    final original = trip.expenses.first;
    await tester.pumpWidget(_wrap(LedgerScreen(trip: trip)));
    await tester.ensureVisible(find.text(original.place));
    await tester.tap(find.text(original.place));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('2026.10.01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026.10.01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(trip.expenses.first.date, DateTime(2026, 10, 4, 10, 1));
  });

  testWidgets('빈 장부는 첫 기록을 안내한다', (tester) async {
    trip.expenses.clear();
    await tester.pumpWidget(_wrap(LedgerScreen(trip: trip)));
    expect(find.text('아직 기록한 지출이 없어요'), findsOneWidget);
    await tester.tap(find.text('지출 기록'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
  });

  testWidgets('320px 화면에서도 장부·입력 화면이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(LedgerScreen(trip: trip)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('지출 기록'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '999999999999',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('원격 수정·삭제도 같은 문서와 로컬 목록에 반영된다', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreTripRepository(uid: 'test', db: db);
    await repo.saveTrip(trip);
    await repo.saveExpense(trip.id, trip.expenses.first);
    tripStore.connect(repo);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final loaded = tripStore.byId(trip.id)!;
    final changed = Expense(
      id: 'e1',
      icon: '🍜',
      place: '수정',
      amount: 2000,
      date: loaded.expenses.first.date,
    );
    await tripStore.saveExpense(trip.id, changed);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loaded.expenses.single.amount, 2000);
    await tripStore.deleteExpense(trip.id, 'e1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loaded.expenses, isEmpty);
    expect(
      (await db
              .collection('users')
              .doc('test')
              .collection('trips')
              .doc(trip.id)
              .collection('records')
              .get())
          .docs,
      isEmpty,
    );
  });

  test('원격 실패는 성공으로 처리하지 않으며 기록이 유지된다', () async {
    final db = FakeFirebaseFirestore();
    final normal = FirestoreTripRepository(uid: 'test', db: db);
    await normal.saveTrip(trip);
    await normal.saveExpense(trip.id, trip.expenses.first);
    tripStore.connect(_FailingRepository(db));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final loaded = tripStore.byId(trip.id)!;
    await expectLater(
      tripStore.saveExpense(trip.id, trip.expenses[1]),
      throwsStateError,
    );
    await expectLater(tripStore.deleteExpense(trip.id, 'e1'), throwsStateError);
    expect(loaded.expenses.single.id, 'e1');
    expect(loaded.expenses.single.amount, 1501);
  });

  testWidgets('저장 실패 시 입력 화면과 기존 지출이 유지된다', (tester) async {
    await tester.runAsync(() async {
      final db = FakeFirebaseFirestore();
      final normal = FirestoreTripRepository(uid: 'test', db: db);
      await normal.saveTrip(trip);
      await normal.saveExpense(trip.id, trip.expenses.first);
      tripStore.connect(_FailingRepository(db));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final loaded = tripStore.byId(trip.id)!;
    await tester.pumpWidget(_wrap(LedgerScreen(trip: loaded)));
    await tester.tap(find.text('상점1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '2000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-place')),
      '보존할 입력',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.text('보존할 입력'), findsOneWidget);
    expect(find.text('2,000'), findsOneWidget);
    expect(find.text('저장하지 못했어요. 입력 내용을 유지했으니 다시 시도해주세요.'), findsOneWidget);
    expect(loaded.expenses.single.amount, 1501);
  });
}
