import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:tripapp/trip_home/screens/card_connection_screen.dart';
import 'package:tripapp/trip_home/screens/expense_detail_screen.dart';
import 'package:tripapp/trip_home/screens/rates_screen.dart';
import 'package:tripapp/trip_home/services/card_sync_api.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';
import 'package:tripapp/trip_home/widgets/recent_expenses_card.dart';
import 'package:tripapp/trip_home/widgets/expense_tile.dart';
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
        paymentMethod: PaymentMethod.cash,
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
    await tester.ensureVisible(find.text('카드'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카드'));
    await tester.ensureVisible(find.text('면세 적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('면세 적용'));
    await tester.ensureVisible(find.text('🛍 쇼핑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🛍 쇼핑'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(TripHomeScreen), findsOneWidget);
    expect(trip.expenses.length, 4);
    expect(trip.expenses.last.amount, 1000);
    expect(trip.expenses.last.category, '쇼핑');
    expect(trip.expenses.last.paymentMethod, PaymentMethod.card);
    expect(trip.expenses.last.isTaxFree, isTrue);
    expect(trip.spentKrw, 47434);
    expect(find.text('47,434원'), findsOneWidget);
    await tester.tap(find.text('장부 보기'));
    await tester.pumpAndSettle();
    expect(find.text('47,434원'), findsOneWidget);
    expect(find.text('현금 38,814원'), findsOneWidget);
    expect(find.text('카드 8,620원'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('편의점'), 200);
    await tester.pumpAndSettle();
    expect(find.text('편의점'), findsOneWidget);
    expect(find.text('카드 · 면세'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('결제수단을 선택해야 저장되며 면세 금액을 이중 차감하지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(ExpenseFormScreen(trip: trip)));
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '1000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-place')),
      '면세 결제',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(trip.expenses.length, 3);
    await tester.ensureVisible(find.text('결제수단을 선택해주세요'));
    await tester.pumpAndSettle();
    expect(find.text('결제수단을 선택해주세요'), findsOneWidget);
    await tester.ensureVisible(find.text('현금'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('현금'));
    await tester.pump();
    expect(find.text('결제수단을 선택해주세요'), findsNothing);
    await tester.ensureVisible(find.text('면세 적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('면세 적용'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final added = trip.expenses.last;
    expect(added.paymentMethod, PaymentMethod.cash);
    expect(added.isTaxFree, isTrue);
    expect(added.amount, 1000);
    expect(trip.spentKrw, 47434);
  });

  testWidgets('수정은 ID·날짜를 유지하며 삭제 취소와 확인을 구분한다', (tester) async {
    final original = trip.expenses.first;
    await tester.pumpWidget(_wrap(LedgerScreen(trip: trip)));
    await tester.scrollUntilVisible(find.text('상점1'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('상점1'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
    await tester.tap(find.text('수정'));
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
    await tester.ensureVisible(find.text('카드'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카드'));
    await tester.ensureVisible(find.text('면세 적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('면세 적용'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(trip.expenses.length, 3);
    final updated = trip.expenses.firstWhere((e) => e.id == original.id);
    expect(updated.date, original.date);
    expect(updated.amount, 2000);
    expect(updated.paymentMethod, PaymentMethod.card);
    expect(updated.isTaxFree, isTrue);
    expect(trip.spentKrw, 43116);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('카드'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '카드')).selected,
      isTrue,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('현금'));
    await tester.ensureVisible(find.text('면세 적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('면세 적용'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(trip.expenses.first.paymentMethod, PaymentMethod.cash);
    expect(trip.expenses.first.isTaxFree, isFalse);
    expect(trip.spentKrw, 43116);
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
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
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '1000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-place')),
      '올바른 사용처',
    );
    await tester.pump();
    expect(find.text('금액은 1 이상 입력해주세요'), findsNothing);
    expect(find.text('사용처를 입력해주세요'), findsNothing);
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
    await tester.scrollUntilVisible(find.text(original.place), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text(original.place));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
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
    await tester.scrollUntilVisible(find.text('아직 기록한 지출이 없어요'), 150);
    await tester.pumpAndSettle();
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
      paymentMethod: PaymentMethod.card,
      isTaxFree: true,
      date: loaded.expenses.first.date,
    );
    await tripStore.saveExpense(trip.id, changed);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loaded.expenses.single.amount, 2000);
    expect(loaded.expenses.single.paymentMethod, PaymentMethod.card);
    expect(loaded.expenses.single.isTaxFree, isTrue);
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

  test('결제수단·면세 필드가 없는 기존 문서를 그대로 읽는다', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreTripRepository(uid: 'test', db: db);
    final records = db
        .collection('users')
        .doc('test')
        .collection('trips')
        .doc(trip.id)
        .collection('records');
    await repo.saveExpense(trip.id, trip.expenses.first);
    await records.doc('e1').update({
      'paymentMethod': FieldValue.delete(),
      'isTaxFree': FieldValue.delete(),
    });
    final old = (await repo.watchExpenses(trip.id).first).single;
    expect(old.paymentMethod, isNull);
    expect(old.isTaxFree, isFalse);
    expect(old.amount, 1501);
    await records.doc('e1').update({'paymentMethod': 'unknown'});
    expect(
      (await repo.watchExpenses(trip.id).first).single.paymentMethod,
      isNull,
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
    await tester.scrollUntilVisible(find.text('상점1'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('상점1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
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

  test('통화별 항목 합계·취소 제외·D-day가 같은 기준으로 계산된다', () {
    trip.expenses.addAll([
      Expense(
        id: 'usd',
        icon: '🛍',
        place: '달러 지출',
        amount: 10.9,
        currency: 'USD',
        date: DateTime(2026, 10, 2),
      ),
      Expense(
        id: 'cancel',
        icon: '💳',
        place: '취소',
        amount: 0,
        originalAmount: 1000,
        currency: 'JPY',
        status: ExpenseStatus.cancelled,
        date: DateTime(2026, 10, 2),
      ),
    ]);
    expect(trip.spentKrw, 52314);
    expect(trip.dayLabel(DateTime(2026, 9, 30)), 'D-1');
    expect(trip.dayLabel(DateTime(2026, 10, 1)), 'D-day');
    expect(trip.dayLabel(DateTime(2026, 10, 3)), 'D+2');
    expect(trip.dayLabel(DateTime(2026, 10, 6)), '여행 완료');
  });

  testWidgets('결제수단·카테고리·정렬을 조합하고 빈 필터를 안내한다', (tester) async {
    trip.expenses.add(
      Expense(
        id: 'shop',
        icon: '🛍',
        place: '큰 쇼핑',
        amount: 10000,
        category: '쇼핑',
        paymentMethod: PaymentMethod.card,
        date: DateTime(2026, 10, 2),
      ),
    );
    await tester.pumpWidget(_wrap(LedgerScreen(trip: trip)));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ledger-payment-card')),
      150,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ledger-payment-card')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('큰 쇼핑'), 150);
    await tester.pumpAndSettle();
    expect(find.text('상점1'), findsNothing);
    await tester.ensureVisible(find.text('카테고리별'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카테고리별'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('금액순'));
    await tester.pumpAndSettle();
    expect(find.text('🛍 쇼핑 · 1건'), findsOneWidget);
    trip.expenses.removeWhere((e) => e.id == 'shop');
    tripStore.rename(trip.id, trip.name);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 결제수단으로 기록한 지출이 없어요'), 150);
    expect(find.text('이 결제수단으로 기록한 지출이 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('통화 선택·메모·현재 환산·기록 당시 환율을 저장하고 상세에서 읽는다', (tester) async {
    await tester.pumpWidget(_wrap(ExpenseFormScreen(trip: trip)));
    await tester.tap(find.byKey(const ValueKey('expense-currency')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('🇰🇷 KRW · 원').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇰🇷 KRW · 원').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '1000.9',
    );
    await tester.enterText(
      find.byKey(const ValueKey('expense-place')),
      '한국 결제',
    );
    await tester.ensureVisible(find.text('현금'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('현금'));
    await tester.ensureVisible(find.byKey(const ValueKey('expense-memo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-memo')),
      '기념품 메모',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final saved = trip.expenses.last;
    expect(saved.currency, 'KRW');
    expect(saved.amount, 1000);
    expect(saved.memo, '기념품 메모');
    expect(saved.recordedQuote, 1);
    // 저장으로 닫힌 Navigator를 재사용하지 않고 상세 화면을 새로 연다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _wrap(ExpenseDetailScreen(trip: trip, expenseId: saved.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text('현재 환산 1,000원'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('기념품 메모'), 150);
    expect(find.text('기념품 메모'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('취소 내역의 외화 표시도 현재 환산액과 같은 순결제액을 사용한다', (tester) async {
    final partial = Expense(
      id: 'partial',
      icon: '💳',
      place: '부분 취소 상점',
      date: DateTime(2026, 10, 3),
      amount: 500,
      originalAmount: 1000,
      status: ExpenseStatus.partiallyCancelled,
      paymentMethod: PaymentMethod.card,
      currency: 'JPY',
    );
    final cancelled = Expense(
      id: 'cancelled',
      icon: '💳',
      place: '취소 상점',
      date: DateTime(2026, 10, 3),
      amount: 1000,
      originalAmount: 1000,
      status: ExpenseStatus.cancelled,
      currency: 'JPY',
    );
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Column(
            children: [
              ExpenseTile(trip: trip, expense: partial),
              ExpenseTile(trip: trip, expense: cancelled),
            ],
          ),
        ),
      ),
    );
    expect(find.text('¥500 JPY'), findsOneWidget);
    expect(find.text('4,310원'), findsOneWidget);
    expect(find.text('¥0 JPY'), findsOneWidget);
    expect(find.text('0원'), findsOneWidget);
    expect(find.text('¥1,000 JPY'), findsNothing);
    trip.expenses.add(partial);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _wrap(ExpenseDetailScreen(trip: trip, expenseId: partial.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥500 JPY'), findsWidgets);
    expect(find.text('현재 환산 4,310원'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('승인 당시 금액'), 150);
    expect(find.text('¥1,000 JPY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('환율 화면은 실제 정수 환율과 통화별 빠른 환산을 사용한다', (tester) async {
    await tester.pumpWidget(_wrap(RatesScreen(country: trip.country)));
    await tester.pumpAndSettle();
    expect(find.text('¥100 = ₩862'), findsOneWidget);
    await tester.tap(find.text('USD · 달러'));
    await tester.pumpAndSettle();
    expect(find.text('USD → KRW'), findsOneWidget);
    expect(find.textContaining('+1.2%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('테스트 승인·중복·부분취소·전체취소가 바로 장부에 반영된다', (tester) async {
    final before = trip.spentKrw;
    await tester.pumpWidget(_wrap(CardConnectionScreen(trip: trip)));
    await tester.tap(find.text('테스트 카드 연결'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('테스트 승인 · 1,000 JPY'));
    await tester.pumpAndSettle();
    expect(trip.spentKrw, before + 8620);
    expect(trip.expenses.length, 4);
    await tester.scrollUntilVisible(find.text('동일 이벤트 재수신'), 100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('동일 이벤트 재수신'));
    await tester.pumpAndSettle();
    expect(trip.expenses.length, 4);
    await tester.tap(find.text('테스트 부분 취소 · 500'));
    await tester.pumpAndSettle();
    expect(trip.spentKrw, before + 4310);
    await tester.tap(find.text('테스트 전체 취소'));
    await tester.pumpAndSettle();
    expect(trip.spentKrw, before);
    final cancelled = trip.expenses.last;
    await tripStore.deleteExpense(trip.id, cancelled.id);
    await tripStore.applyDemoCardEvent(trip.id, cancelled);
    expect(trip.expenses.length, 3); // 숨긴 내역은 재수신해도 되살리지 않는다.
    expect(tester.takeException(), isNull);
  });

  test('Firestore 카드 내역 갱신·통화·메모·숨김이 구독에 반영된다', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreTripRepository(uid: 'test', db: db);
    await repo.saveTrip(trip);
    await repo.saveExpense(
      trip.id,
      Expense(
        id: 'card_1',
        icon: '💳',
        place: '카드 상점',
        amount: 1000,
        originalAmount: 1000,
        source: 'codef',
        currency: 'JPY',
        memo: '선물',
        recordedQuote: 862,
        paymentMethod: PaymentMethod.card,
        date: DateTime(2026, 10, 2),
      ),
    );
    tripStore.connect(repo);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final loaded = tripStore.byId(trip.id)!;
    expect(loaded.expenses.single.memo, '선물');
    expect(loaded.expenses.single.currency, 'JPY');
    final ref = db.doc('users/test/trips/${trip.id}/records/card_1');
    await ref.update({'amount': 500, 'status': 'partiallyCancelled'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loaded.spentKrw, 4310);
    await ref.update({'amount': 0, 'status': 'cancelled'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loaded.spentKrw, 0);
    await tripStore.deleteExpense(trip.id, 'card_1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loaded.expenses, isEmpty);
    expect((await ref.get()).data()?['hidden'], true);
  });

  test('카드 동기화 요청은 인증 토큰·여행 ID만 보내고 실패를 표시한다', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(jsonDecode(request.body), {'tripId': 'ledger'});
      return http.Response('{"received":2,"skipped":1}', 200);
    });
    final result = await CardSyncApi.synchronize(
      tripId: 'ledger',
      idToken: 'test-token',
      client: client,
      endpoint: Uri.parse('https://example.invalid/sync'),
    );
    expect(result.received, 2);
    expect(result.skipped, 1);
    client.close();
    final failed = MockClient((_) async => http.Response('{}', 409));
    await expectLater(
      CardSyncApi.synchronize(
        tripId: 'ledger',
        idToken: 'test-token',
        client: failed,
        endpoint: Uri.parse('https://example.invalid/sync'),
      ),
      throwsStateError,
    );
    failed.close();
  });

  testWidgets('자동 기록의 메모 수정은 원금·취소 상태·알 수 없는 과거 환율을 보존한다', (tester) async {
    final imported = Expense(
      id: 'fractional',
      icon: '💳',
      place: '자동 결제',
      amount: 12.75,
      originalAmount: 25.50,
      status: ExpenseStatus.partiallyCancelled,
      currency: 'USD',
      source: 'demo-card',
      paymentMethod: PaymentMethod.card,
      date: DateTime(2026, 10, 1),
    );
    trip.expenses.add(imported);
    await tester.pumpWidget(
      _wrap(ExpenseFormScreen(trip: trip, expense: imported)),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('expense-memo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('expense-memo')),
      '메모만 변경',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final saved = trip.expenses.last;
    expect(saved.amount, 12.75);
    expect(saved.originalAmount, 25.50);
    expect(saved.status, ExpenseStatus.partiallyCancelled);
    expect(saved.recordedQuote, isNull);
    expect(saved.memo, '메모만 변경');
  });
}
