import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart';
import 'package:tripapp/trip_home/app.dart';
import 'package:tripapp/trip_home/receipts/receipt_consent.dart';
import 'package:tripapp/trip_home/data/trip_repository.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/spending_summary.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/receipts/receipt_draft.dart';
import 'package:tripapp/trip_home/receipts/receipt_screen.dart';
import 'package:tripapp/trip_home/screens/expense_form_screen.dart';
import 'package:tripapp/trip_home/screens/expense_detail_screen.dart';
import 'package:tripapp/trip_home/screens/spending_overview_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/screens/trip_list_screen.dart';
import 'package:tripapp/trip_home/screens/ledger_screen.dart';
import 'package:tripapp/trip_home/screens/empty_home_screen.dart';
import 'package:tripapp/trip_home/screens/add_trip_screen.dart';
import 'package:tripapp/trip_home/screens/more_screen.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';
import 'package:tripapp/trip_home/widgets/calendar_range_picker.dart';
import 'package:tripapp/trip_home/widgets/category_charts.dart';
import 'package:tripapp/trip_home/widgets/expense_tile.dart';
import 'package:tripapp/trip_home/widgets/sheets.dart';
import 'package:tripapp/trip_home/widgets/swipe_actions.dart';
import 'package:tripapp/trip_home/widgets/onboarding_example.dart';
import 'package:tripapp/trip_home/widgets/rate_info_tooltip.dart';
import 'package:tripapp/trip_home/widgets/screen_top_bar.dart';
import 'package:tripapp/trip_home/widgets/quick_converter.dart';
import 'package:tripapp/trip_home/theme/app_colors.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(body: child),
);
Trip trip([List<Expense>? entries]) => Trip(
  id: 'qa',
  name: '테스트 여행',
  country: countryByIso('JP')!,
  start: DateTime(2026, 10, 1),
  end: DateTime(2026, 10, 5),
  budgetKrw: 100000,
  expenses: entries,
);
Expense expense(
  String id,
  double amount, {
  String code = 'KRW',
  String category = '식비',
  ExpenseStatus status = ExpenseStatus.approved,
  double? original,
  String? receipt,
}) => Expense(
  id: id,
  icon: '🍜',
  place: '테스트 카페',
  amount: amount,
  currency: code,
  category: category,
  date: DateTime(2026, 10, 2),
  status: status,
  originalAmount: original,
  paymentMethod: PaymentMethod.cash,
  receiptFingerprint: receipt,
);
Future<void> rates() async {
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
            c.currency: c.unitAmount / c.krwPerUnit,
        },
      }),
      200,
    ),
  );
  await RateApi.load(force: true, client: client);
  client.close();
}

void main() {
  setUp(() async {
    RateApi.reset();
    SharedPreferences.setMockInitialValues({
      'trip_guide_seen': true,
      receiptConsentKey(Uri.parse(receiptServerOrigin)): true,
    });
    tripStore.connect(null);
    await rates();
  });
  tearDown(() => tripStore.connect(null));
  testWidgets(
    'calendar fixed six rows, stationary arrows and browse-only selection across years',
    (tester) async {
      DateRange? picked;
      await tester.pumpWidget(
        wrap(
          CalendarRangePicker(
            initialMonth: DateTime(2026, 2),
            initialRange: DateRange(
              DateTime(2026, 2, 8),
              DateTime(2026, 2, 10),
            ),
            onChanged: (range) => picked = range,
          ),
        ),
      );
      final size = tester.getSize(find.byType(CalendarRangePicker));
      final arrow = tester.getCenter(find.byTooltip('다음 달'));
      for (var i = 0; i < 14; i++) {
        await tester.tap(find.byTooltip('다음 달'));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(CalendarRangePicker)), size);
        expect(tester.getCenter(find.byTooltip('다음 달')), arrow);
      }
      expect(find.text('2027년 4월'), findsOneWidget);
      expect(picked, isNull);
      for (var i = 0; i < 14; i++) {
        await tester.tap(find.byTooltip('이전 달'));
        await tester.pump();
      }
      final selected = tester.widgetList<Semantics>(
        find.ancestor(of: find.text('8'), matching: find.byType(Semantics)),
      );
      expect(selected.any((s) => s.properties.selected == true), isTrue);
    },
  );
  testWidgets(
    'direct leap-year/month jump, Escape cancellation and focus return',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          CalendarRangePicker(
            initialMonth: DateTime(2027, 5),
            onChanged: (_) {},
          ),
        ),
      );
      final title = find.widgetWithText(TextButton, '2027년 5월');
      await tester.tap(title);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('calendar-year')),
        '2028',
      );
      await tester.tap(find.text('2월'));
      await tester.tap(find.text('이동'));
      await tester.pumpAndSettle();
      expect(find.text('29'), findsOneWidget);
      final node = tester
          .widget<TextButton>(find.widgetWithText(TextButton, '2028년 2월'))
          .focusNode!;
      expect(node.hasFocus, isTrue);
      await tester.tap(find.text('2028년 2월'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('연도와 월 선택'), findsNothing);
      expect(node.hasFocus, isTrue);
    },
  );
  testWidgets(
    'range taps across months, reverse ordering, keyboard navigation does not select',
    (tester) async {
      DateRange? picked;
      await tester.pumpWidget(
        wrap(
          CalendarRangePicker(
            initialMonth: DateTime(2028, 2),
            onChanged: (r) => picked = r,
          ),
        ),
      );
      await tester.tap(find.text('29'));
      await tester.pump();
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      expect(picked!.start, DateTime(2028, 2, 29));
      expect(picked!.end, DateTime(2028, 3, 2));
      await tester.tap(find.text('10'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(picked!.start, DateTime(2028, 3, 5));
      expect(picked!.end, DateTime(2028, 3, 10));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(picked!.start, DateTime(2028, 3, 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(picked!.start, DateTime(2028, 3, 6));
    },
  );
  test('range validation is enforced before storage mutation', () {
    final t = trip();
    expect(DateRange(DateTime(2028, 2, 29), DateTime(2028, 3, 1)).nights, 1);
    expect(
      DateRange(DateTime(2026, 3, 2), DateTime(2026, 3, 1)).isValid,
      isFalse,
    );
    t.end = DateTime(2026, 9, 30);
    expect(() => tripStore.add(t), throwsArgumentError);
    expect(tripStore.isEmpty, isTrue);
    t.end = DateTime(2026, 10, 5);
    tripStore.add(t);
    expect(
      () => tripStore.update(t.id, end: DateTime(2026, 9, 30)),
      throwsArgumentError,
    );
    expect(t.end, DateTime(2026, 10, 5));
    tripStore.update(
      t.id,
      start: DateTime(2026, 10, 1, 23),
      end: DateTime(2026, 10, 1),
    );
    expect(t.start.day, t.end.day);
  });
  test(
    '249 countries have stable distinct ISO codes; currencies stay unique',
    () {
      expect(kCountries.length, 249);
      expect(kCountries.map((c) => c.code).toSet().length, 249);
      expect(
        kExpenseCurrencies.map((c) => c.currency).toSet().length,
        kExpenseCurrencies.length,
      );
      expect(countryByIso('FR')!.currency, countryByIso('DE')!.currency);
      expect(countryByIso('AU')!.matches('호주'), isTrue);
      expect(countryByIso('JP')!.matches('JAPAN'), isTrue);
    },
  );
  testWidgets(
    'country search/clear/no matches/current selection and 320px keyboard fit',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              viewInsets: EdgeInsets.only(bottom: 250),
            ),
            child: MoreCountrySheet(initialSelected: countryByIso('FR')),
          ),
        ),
      );
      expect(find.text('선택: 프랑스'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('country-search')),
        'germany',
      );
      await tester.pump();
      await tester.tap(find.text('독일'));
      await tester.pump();
      expect(find.text('선택: 독일'), findsOneWidget);
      expect(tester.widget<ListTile>(find.byType(ListTile)).selected, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('country-search')),
        '없는국가zz',
      );
      await tester.pump();
      expect(find.text('검색 결과가 없어요'), findsOneWidget);
      await tester.tap(find.byTooltip('검색어 지우기'));
      await tester.pump();
      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('country-list')),
      );
      expect(
        (list.childrenDelegate as SliverChildBuilderDelegate).childCount,
        249,
      );
      await tester.drag(
        find.byKey(const ValueKey('country-list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'ISO country restoration is independent of shared EUR; legacy currency records still load',
    () async {
      final db = FakeFirebaseFirestore();
      final repository = FirestoreTripRepository(uid: 'qa', db: db);
      final t = trip();
      t.country = countryByIso('DE')!;
      await repository.saveTrip(t);
      final loaded = await repository.watchTrips().first;
      expect(loaded.single.country.code, 'DE');
      expect(loaded.single.country.name, '독일');
      await db
          .collection('users')
          .doc('qa')
          .collection('trips')
          .doc(t.id)
          .update({'countryCode': FieldValue.delete()});
      expect(
        (await repository.watchTrips().first).single.country.currency,
        'EUR',
      );
    },
  );
  test(
    'same conversion, positive pie, negative refunds, cancellations, unknown category and zero',
    () {
      final t = trip([
        expense('a', 100, code: 'JPY'),
        expense('b', 500, category: '교통'),
        expense('c', -200),
        expense('d', 0),
        expense('e', 300, category: '새분류'),
        expense('f', 0, status: ExpenseStatus.cancelled, original: 1000),
        expense(
          'g',
          400,
          status: ExpenseStatus.partiallyCancelled,
          original: 1000,
        ),
        expense('h', 900, status: ExpenseStatus.declined),
      ]);
      final summary = SpendingSummary(t);
      expect(summary.netKrw, t.spentKrw);
      expect(summary.netKrw, 1950);
      expect(summary.positiveKrw, 2150);
      expect(summary.refundsKrw, 200);
      expect(summary.cancellationsKrw, 1600);
      expect(summary.categories['미분류'], 300);
      expect(
        summary.categories.values.reduce((a, b) => a + b),
        summary.positiveKrw,
      );
      expect(
        summary.categories.keys.fold<double>(0, (s, c) => s + summary.share(c)),
        closeTo(1, 1e-10),
      );
      expect(summary.budgetRatio(t.budgetKrw), t.spentRatio);
      expect(categoryColor('숙소'), categoryColor('숙박'));
      expect(SpendingSummary(trip([expense('z', 0)])).positiveKrw, 0);
      expect(SpendingSummary(trip([])).share('식비'), 0);
    },
  );
  testWidgets(
    'missing rate shows currency-separated totals, not a pie or mixed raw sum',
    (tester) async {
      final t = trip([expense('a', 100), expense('b', 200, code: 'AED')]);
      final summary = SpendingSummary(t);
      expect(summary.available, isFalse);
      expect(summary.originalCurrencyTotals, {'KRW': 100, 'AED': 200});
      await tester.pumpWidget(wrap(SpendingOverviewScreen(trip: t)));
      expect(find.text('환율 확인 필요'), findsOneWidget);
      expect(find.byType(CategoryPie), findsNothing);
      expect(find.text('KRW 100'), findsOneWidget);
      expect(find.text('AED 200'), findsOneWidget);
    },
  );

  testWidgets(
    'home never shows a partial KRW total when another expense lacks a rate',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final t = trip([expense('a', 1000), expense('b', 200, code: 'AED')]);
      await tester.pumpWidget(wrap(TripHomeScreen(trip: t)));
      expect(find.text('환율 없음'), findsWidgets);
      expect(find.text('통화별 표시'), findsNothing);
      expect(
        tester.widget<Text>(find.text('환율 없음').first).style!.fontSize,
        36,
      ); // 주요 합계가 누락 통화를 빼고 부분 합산한 금액으로 표시되지 않는다.
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'cancelled unknown currency does not block valid net totals; refunds-only has no pie',
    () {
      final cancelled = SpendingSummary(
        trip([
          expense('a', 1000),
          expense(
            'b',
            0,
            code: 'AED',
            status: ExpenseStatus.cancelled,
            original: 50,
          ),
        ]),
      );
      expect(cancelled.available, isTrue);
      expect(cancelled.netKrw, 1000);
      expect(cancelled.unconvertedCancellations['AED'], 50);
      final refunded = SpendingSummary(trip([expense('r', -500)]));
      expect(refunded.netKrw, -500);
      expect(refunded.categories, isEmpty);
      expect(refunded.budgetRatio(0), 0);
      expect(refunded.budgetRatio(1000), 0);
      expect(
        SpendingSummary(trip([expense('a', 150000)])).budgetRatio(100000),
        1,
      );
    },
  );
  testWidgets(
    'overview and budget totals react after add, edit, delete without a duplicate expense list',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final t = trip([expense('a', 1000)]);
      tripStore.add(t);
      await tester.pumpWidget(wrap(SpendingOverviewScreen(trip: t)));
      expect(find.text('총 순지출 1,000원'), findsOneWidget);
      await tripStore.saveExpense(t.id, expense('b', 2000, category: '교통'));
      await tester.pump();
      expect(find.text('총 순지출 3,000원'), findsOneWidget);
      await tripStore.saveExpense(t.id, expense('a', 3000));
      await tester.pump();
      expect(find.text('총 순지출 5,000원'), findsOneWidget);
      await tripStore.deleteExpense(t.id, 'b');
      await tester.pump();
      expect(find.text('총 순지출 3,000원'), findsOneWidget);
      expect(find.byType(ExpenseTile), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(wrap(CategoryBudgetBar(trip: t)));
      expect(SpendingSummary(t).budgetRatio(t.budgetKrw), t.spentRatio);
    },
  );
  test(
    'receipt parser extracts final total, never sums subtotal and tax; ambiguous fields require review',
    () {
      final draft = ReceiptDraft.parse(
        'TEST CAFE\n2026-10-04\nSUBTOTAL KRW 10,000\nTAX KRW 1,000\nTOTAL KRW 11,000',
      );
      expect(draft.merchant, 'TEST CAFE');
      expect(draft.date, DateTime(2026, 10, 4));
      expect(draft.amount, 11000);
      expect(draft.currency, 'KRW');
      expect(draft.category, '식비');
      expect(draft.warnings, isEmpty);
      final ambiguous = ReceiptDraft.parse(
        'TEST SHOP\n04/10/26\nTOTAL ¥1,500\nTOTAL ¥1,600',
        confidence: 30,
      );
      expect(ambiguous.amount, isNull);
      expect(ambiguous.currency, isNull);
      expect(ambiguous.date, isNull);
      expect(ambiguous.warnings.length, greaterThanOrEqualTo(4));
      expect(
        ReceiptDraft.parse('SHOP\n2026-02-30\nTOTAL EUR 1.234,56').amount,
        isNull,
      );
      expect(
        ReceiptDraft.parse('SHOP\n2026-02-30\nTOTAL JPY 100').date,
        isNull,
      );
      expect(ReceiptDraft.parse('SHOP\nTOTAL USD 10.50').amount, 10.5);
      final japanese = ReceiptDraft.parse(
        'テストカフェ\n2028年2月29日\n小計 1000円\n合計 1100円',
      );
      expect(japanese.date, DateTime(2028, 2, 29));
      expect(japanese.currency, 'JPY');
      expect(japanese.amount, 1100);
    },
  );
  testWidgets(
    'receipt review does not auto-save and cancellation leaves store untouched',
    (tester) async {
      final bytes = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7k0AAAAASUVORK5CYII=',
        ),
      );
      final draft = ReceiptDraft.parse(
        'TEST CAFE\n2026-10-04\nTOTAL KRW 11000',
      );
      ReceiptDraft? result;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<ReceiptDraft>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReceiptReviewScreen(draft: draft, image: bytes),
                  ),
                );
              },
              child: const Text('영수증 검토 열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('영수증 검토 열기'));
      await tester.pumpAndSettle();
      expect(tripStore.isEmpty, isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '확인 후 지출 양식에 적용'),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '확인 후 지출 양식에 적용'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tripStore.isEmpty, isTrue);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('영수증 검토 열기'), findsOneWidget);
      expect(tripStore.isEmpty, isTrue);
    },
  );
  testWidgets(
    'receipt line items survive storage and appear in expandable expense details',
    (tester) async {
      // Transcription fixture tests parsing/storage/UI, not image-recognition accuracy.
      final draft = ReceiptDraft.parse(
        '페이히어 이용 가이드\n주문번호 #1\n카드결제승인\n페이히어 카페\n2024-08-21\n상품명 단가 수량 금액\nAmericano 5,000 1 5,000\n합계 5,000원\n공급가액 4,545원\n부가세 455원\n결제금액 5,000원',
      );
      expect(draft.merchant, '페이히어 카페');
      expect(draft.amount, 5000);
      expect(draft.currency, 'KRW');
      expect(draft.items.single.name, 'Americano');
      expect(draft.items.single.quantity, 1);
      expect(draft.items.single.amount, 5000);
      expect(
        ReceiptDraft.parse('카페\nAmericano 5,000 2 5,000\n결제금액 5,000원').items,
        isEmpty,
      );
      final db = FakeFirebaseFirestore();
      final repo = FirestoreTripRepository(uid: 'receipt-test', db: db);
      final t = trip([]);
      await repo.saveTrip(t);
      final e = Expense(
        id: 'receipt',
        icon: '🍜',
        place: draft.merchant,
        amount: draft.amount!,
        currency: draft.currency,
        date: draft.date!,
        receiptItems: draft.items,
      );
      await repo.saveExpense(t.id, e);
      t.expenses.addAll(await repo.watchExpenses(t.id).first);
      expect(
        t.spentKrw,
        5000,
      ); // Items are not added again to the expense amount.
      expect(t.expenses.single.receiptItems.single.quantity, 1);
      await tester.pumpWidget(
        wrap(ExpenseDetailScreen(trip: t, expenseId: e.id)),
      );
      expect(find.text('Americano'), findsNothing);
      await tester.tap(find.text('품목 상세 (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Americano'), findsOneWidget);
      expect(find.text('수량 1'), findsOneWidget);
      expect(find.text('5,000 KRW'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'duplicate receipt prompts allow legitimate separate expenses; cancel and double click are safe',
    (tester) async {
      final t = trip([
        expense('a', 1000, receipt: 'same'),
        expense('b', 1000, receipt: 'same'),
      ]);
      tripStore.add(t);
      await tester.pumpWidget(
        wrap(ExpenseFormScreen(trip: t, expense: t.expenses.last)),
      );
      final save = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장'))
          .onPressed!;
      save();
      save();
      await tester.pumpAndSettle();
      expect(find.text('같은 영수증일 수 있어요'), findsOneWidget);
      await tester.tap(find.text('돌아가서 확인'));
      await tester.pumpAndSettle();
      expect(t.expenses.length, 2);
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('별개 지출로 저장'));
      await tester.pumpAndSettle();
      expect(t.expenses.length, 2);
      expect(t.expenses.map((e) => e.id).toSet().length, 2);
    },
  );

  testWidgets(
    'list and pie have separate home links; category details are collapsed by default',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final t = trip([expense('a', 1000)]);
      tripStore.add(t);
      await tester.pumpWidget(wrap(TripHomeScreen(trip: t)));
      expect(find.text('식비 100.0%'), findsNothing);
      final amount = tester.widget<Text>(find.text('1,000원').first);
      expect(amount.style!.color, AppColors.white);
      await tester.tap(
        find.byKey(const ValueKey('spending-categories-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('식비 100.0%'), findsOneWidget);
      await tripStore.saveExpense(t.id, expense('b', 1000, category: '교통'));
      await tester.pump();
      expect(find.text('식비 50.0%'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('spending-categories-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('식비 50.0%'), findsNothing);
      await tester.ensureVisible(find.text('지출보기'));
      await tester.tap(find.text('지출보기'));
      await tester.pumpAndSettle();
      expect(find.byType(LedgerScreen), findsOneWidget);
      expect(find.byType(CategoryPie), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('한눈에 보기'));
      await tester.tap(find.text('한눈에 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(SpendingOverviewScreen), findsOneWidget);
      expect(find.byType(CategoryPie), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home previews have no click, hover, long-press or swipe actions',
    (tester) async {
      final t = trip([expense('a', 1000)]);
      tripStore.add(t);
      await tester.pumpWidget(wrap(TripHomeScreen(trip: t)));
      final tile = find.byType(ExpenseTile).first;
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: tile, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.byType(SwipeActions)),
        findsNothing,
      );
      await tester.tapAt(tester.getCenter(tile));
      await tester.longPressAt(tester.getCenter(tile));
      await tester.dragFrom(tester.getCenter(tile), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.byType(ExpenseDetailScreen), findsNothing);
      expect(find.byType(ExpenseFormScreen), findsNothing);
      expect(t.expenses.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blue budget panel is flat and pastel categories share the chart palette',
    (tester) async {
      final t = trip([expense('a', 10000)]);
      await tester.pumpWidget(wrap(BudgetProgressPanel(trip: t)));
      final panel = find.byType(BudgetProgressPanel);
      expect(
        find.descendant(of: panel, matching: find.byType(Container)),
        findsNothing,
      );
      final bar = tester.widget<CategoryBudgetBar>(
        find.byType(CategoryBudgetBar),
      );
      expect(bar.height, 8);
      expect(bar.track, AppColors.progressTrackOnPrimary);
      expect(
        tester.widget<Text>(find.text('10%')).style!.color,
        AppColors.white,
      );
      expect(categoryColor('식비'), isNot(AppColors.primary));
      expect(SpendingSummary(t).budgetRatio(t.budgetKrw), .1);
    },
  );

  for (final size in [const Size(390, 844), const Size(375, 812)]) {
    testWidgets('home summaries fit without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final t = trip([
        for (var i = 0; i < 4; i++) expense('$i', 10000, code: 'JPY'),
      ]);
      tripStore.add(t);
      await tester.pumpWidget(wrap(TripHomeScreen(trip: t)));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.maxScrollExtent, 0);
      expect(
        tester.widget<Text>(find.text(formatWon(t.spentKrw))).style!.fontSize,
        36,
      );
      expect(
        tester
            .widget<Text>(find.text(formatWon(t.remainKrw.abs())))
            .style!
            .fontSize,
        16,
      );
      expect(
        tester.widget<Text>(find.text(formatWon(t.budgetKrw))).style!.fontSize,
        16,
      );
      expect(find.textContaining('하루 '), findsNothing);
      expect(find.textContaining('4박 5일'), findsNothing);
      expect(find.byType(ExpenseTile), findsOneWidget);
      expect(t.expenses.length, 4);
      expect(find.text('빠른 환산'), findsOneWidget);
      expect(
        tester.getRect(find.byType(QuickConverter)).bottom,
        lessThan(tester.getRect(find.text('영수증 촬영')).top),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('spending-categories-toggle')))
            .height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(
        find.byKey(const ValueKey('spending-categories-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('식비 100.0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('small screens and large text keep all home content reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final t = trip([expense('a', 10000)]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: TripHomeScreen(trip: t),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(QuickConverter));
    await tester.pumpAndSettle();
    expect(find.text('빠른 환산'), findsOneWidget);
    expect(find.text('영수증 촬영'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'swipe demo repeats slowly and stops when the user takes control',
    (tester) async {
      var edits = 0, deletes = 0;
      await tester.pumpWidget(
        wrap(
          SwipeActions(
            label: '예시',
            previewSwipe: true,
            onEdit: () => edits++,
            onDelete: () => deletes++,
            child: const ColoredBox(
              color: AppColors.white,
              child: SizedBox(height: 120, width: double.infinity),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byTooltip('예시 수정'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byTooltip('예시 수정'), findsOneWidget);
      expect(find.byTooltip('예시 삭제'), findsOneWidget);
      expect(edits + deletes, 0);
      await tester.pump(const Duration(milliseconds: 2200));
      expect(find.byTooltip('예시 수정'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.byTooltip('예시 수정'), findsOneWidget);
      await tester.drag(find.byType(SwipeActions), const Offset(160, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 8));
      expect(find.byTooltip('예시 수정'), findsNothing);
      expect(edits + deletes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'right swipe goes back; left, short, vertical and root gestures are safe',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final t = trip([])
        ..start = now
        ..end = now.add(const Duration(days: 2));
      tripStore.add(t);
      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();
      expect(find.byType(TripHomeScreen), findsOneWidget);
      for (final offset in [
        const Offset(-180, 0),
        const Offset(40, 0),
        const Offset(0, -100),
      ]) {
        await tester.dragFrom(const Offset(80, 160), offset);
        await tester.pumpAndSettle();
        expect(find.byType(TripHomeScreen), findsOneWidget);
      }
      await tester.dragFrom(const Offset(40, 160), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(find.byType(TripListScreen), findsOneWidget);
      expect(find.byType(TripHomeScreen), findsNothing);
      await tester.tap(find.byTooltip('더보기'));
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsOneWidget);
      await tester.dragFrom(const Offset(40, 200), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsNothing);
      await tester.dragFrom(const Offset(40, 90), const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(find.byType(TripListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an open expense closes first, then a right swipe navigates back',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final t = trip([expense('a', 1000)])
        ..start = now
        ..end = now.add(const Duration(days: 2));
      tripStore.add(t);
      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();
      final menu = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.more_horiz_rounded),
      );
      expect((menu.icon as Icon).icon, Icons.more_horiz_rounded);
      await tester.tap(find.text('장부 보기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ExpenseTile).first);
      await tester.pumpAndSettle();
      final row = find.byType(ExpenseTile).first;
      await tester.drag(row, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('테스트 카페 지출 삭제'), findsOneWidget);
      await tester.dragFrom(
        tester.getTopLeft(row) + const Offset(15, 30),
        const Offset(230, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LedgerScreen), findsOneWidget);
      expect(find.byTooltip('테스트 카페 지출 삭제'), findsNothing);
      await tester.dragFrom(
        tester.getTopLeft(row) + const Offset(15, 30),
        const Offset(230, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LedgerScreen), findsNothing);
      expect(find.byType(TripHomeScreen), findsOneWidget);
      expect(t.expenses.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tutorial demonstration autoplays without a button and pauses offscreen',
    (tester) async {
      await tester.pumpWidget(
        wrap(SingleChildScrollView(child: const OnboardingExample(step: 2))),
      );
      expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
      expect(find.text('밀기 동작 다시 보기'), findsNothing);
      expect(find.text('스와이프 예시 보기'), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byTooltip('일본 여행 여행 삭제'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byTooltip('일본 여행 여행 삭제'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2200));
      expect(find.byTooltip('일본 여행 여행 삭제'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.byTooltip('일본 여행 여행 삭제'), findsOneWidget);
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: const OnboardingExample(step: 2, active: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
      await tester.pumpWidget(
        wrap(SingleChildScrollView(child: const OnboardingExample(step: 2))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.tap(find.byTooltip('일본 여행 여행 수정'));
      await tester.pumpAndSettle();
      expect(find.text('여행 이름을 수정했어요'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
      await tester.pump(const Duration(seconds: 8));
      expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
      await tester.tap(find.text('처음부터 해보기'));
      await tester.pump();
      expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tripStore.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('last guide leads directly to welcome with no departure screen', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EmptyHomeScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('다음 안내'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }
    await tester.tap(find.byTooltip('시작하기'));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.flight_rounded), findsNothing);
    expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'receipt guide shows capture, recognition and review without saving',
    (tester) async {
      await tester.pumpWidget(
        wrap(SingleChildScrollView(child: const OnboardingExample(step: 3))),
      );
      await tester.ensureVisible(find.text('촬영해 보기'));
      await tester.tap(find.text('촬영해 보기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('사진 확인 후 인식'));
      await tester.tap(find.text('사진 확인 후 인식'));
      await tester.pumpAndSettle();
      expect(find.text('KRW · 원'), findsOneWidget);
      expect(find.text('2027-05-01'), findsOneWidget);
      expect(find.text('촬영 흐름 보기'), findsNothing);
      expect(tripStore.isEmpty, isTrue);
    },
  );

  testWidgets('home and ledger use identical rate slots at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final t = trip([expense('a', 1000)])..name = '긴 여행 이름을 확인하는 테스트';
    await tester.pumpWidget(wrap(TripHomeScreen(trip: t)));
    final home = tester.getRect(find.byType(CurrentRateBadge));
    expect(find.byType(TripTopBar), findsOneWidget);
    await tester.pumpWidget(wrap(LedgerScreen(trip: t)));
    expect(tester.getRect(find.byType(CurrentRateBadge)), home);
    expect(find.byType(TripTopBar), findsOneWidget);
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('카드 연동'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'travel cards reveal both actions to the left without accidental deletion',
    (tester) async {
      final t = trip([])
        ..start = DateTime(2027, 1, 1)
        ..end = DateTime(2027, 1, 2);
      tripStore.add(t);
      await tester.pumpWidget(wrap(const TripListScreen()));
      final card = find.byKey(ValueKey('trip-swipe-${t.id}'));
      await tester.drag(card, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('${t.name} 여행 삭제'), findsOneWidget);
      expect(tripStore.trips.length, 1);
      await tester.tap(find.byTooltip('${t.name} 여행 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('이 여행을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(tripStore.trips.length, 1);
      await tester.drag(card, const Offset(-180, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('${t.name} 여행 수정'));
      await tester.pumpAndSettle();
      expect(find.byType(TripEditSheet), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.drag(card, const Offset(-180, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('${t.name} 여행 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(tripStore.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ledger expense swipes and long press keep edit and delete confirmation',
    (tester) async {
      {
        tripStore.connect(null);
        final t = trip([expense('a', 1000)]);
        tripStore.add(t);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(wrap(LedgerScreen(trip: t)));
        await tester.scrollUntilVisible(
          find.byType(ExpenseTile),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final tile = find.byType(ExpenseTile).first;
        await tester.pumpAndSettle();
        await tester.drag(tile, const Offset(-180, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('테스트 카페 지출 수정'));
        await tester.pumpAndSettle();
        expect(find.byType(ExpenseFormScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.longPress(tile);
        await tester.pumpAndSettle();
        expect(find.byType(ExpenseFormScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.drag(tile, const Offset(-180, 0));
        await tester.pumpAndSettle();
        expect(t.expenses.length, 1);
        await tester.tap(find.byTooltip('테스트 카페 지출 삭제'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(t.expenses.length, 1);
        await tester.drag(tile, const Offset(-180, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('테스트 카페 지출 삭제'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('삭제'));
        await tester.pumpAndSettle();
        expect(t.expenses, isEmpty);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'swipe keyboard actions, small drags and vertical scrolling are safe',
    (tester) async {
      var edits = 0, deletes = 0, taps = 0;
      await tester.pumpWidget(
        wrap(
          ListView(
            children: [
              for (var i = 0; i < 12; i++)
                SwipeActions(
                  label: '항목$i',
                  onEdit: () => edits++,
                  onDelete: () => deletes++,
                  child: TextButton(
                    onPressed: () => taps++,
                    child: SizedBox(height: 100, child: Text('항목$i')),
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byTooltip('항목0 삭제'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(taps, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byTooltip('항목0 수정'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byTooltip('항목0 수정'), findsNothing);
      await tester.drag(find.text('항목0'), const Offset(20, 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('항목0 삭제'), findsNothing);
      await tester.drag(find.text('항목0'), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(edits, 0);
      expect(deletes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'left-swiped tutorial finishes at a separate welcome, then opens the trip form',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrap(const EmptyHomeScreen()));
      expect(find.text('여행을 추가해요'), findsOneWidget);
      expect(find.text('첫 여행을 추가해 보세요'), findsNothing);
      final pages = find.byKey(const ValueKey('welcome-pages'));
      for (var i = 1; i <= 5; i++) {
        // Swipe the heading, outside the interactive example card.
        await tester.dragFrom(
          tester.getTopLeft(pages) + const Offset(280, 36),
          const Offset(-280, 0),
        );
        if (i == 2) {
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
        }
        if (i < 5) expect(find.text('${i + 1} / 5'), findsOneWidget);
      }
      expect(find.byType(PageView), findsNothing);
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      expect(find.byType(AddTripScreen), findsNothing);
      await tester.tap(find.text('여행 추가하기'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTripScreen), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      await tester.tap(find.text('사용방법 다시 보기'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tutorial buttons support reduced motion and small large-text screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const EmptyHomeScreen(guideOnly: true),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('다음 안내'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('지출을 한눈에 봐요'), findsOneWidget);
      final start = tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
          )
          .onPressed!;
      start();
      start();
      await tester.pumpAndSettle();
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving during guide completion does not navigate or leak a ticker',
    (tester) async {
      await tester.pumpWidget(wrap(const EmptyHomeScreen()));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('다음 안내'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }
      await tester.tap(find.byTooltip('시작하기'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byType(AddTripScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
