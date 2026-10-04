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
import 'package:tripapp/trip_home/data/trip_repository.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/spending_summary.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/receipts/receipt_draft.dart';
import 'package:tripapp/trip_home/receipts/receipt_screen.dart';
import 'package:tripapp/trip_home/screens/expense_form_screen.dart';
import 'package:tripapp/trip_home/screens/spending_overview_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';
import 'package:tripapp/trip_home/widgets/calendar_range_picker.dart';
import 'package:tripapp/trip_home/widgets/category_charts.dart';
import 'package:tripapp/trip_home/widgets/expense_tile.dart';
import 'package:tripapp/trip_home/widgets/sheets.dart';

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
    SharedPreferences.setMockInitialValues({});
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
      expect(find.text('통화별 표시'), findsOneWidget);
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
    'overview/bar/list react together after add, edit, delete on small screen',
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
      await tester.scrollUntilVisible(find.byType(ExpenseTile), 150);
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
                    builder: (_) => ReceiptReviewScreen(
                      draft: draft,
                      image: bytes,
                      text: 'TEST CAFE',
                    ),
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
}
