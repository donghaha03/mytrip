import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/trip_home/data/trip_repository.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/receipt_item.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/receipts/receipt_client.dart';
import 'package:tripapp/trip_home/receipts/receipt_consent.dart';
import 'package:tripapp/trip_home/receipts/receipt_draft.dart';
import 'package:tripapp/trip_home/receipts/receipt_platform_native.dart';
import 'package:tripapp/trip_home/receipts/receipt_screen.dart';
import 'package:tripapp/trip_home/screens/expense_detail_screen.dart';
import 'package:tripapp/trip_home/screens/expense_form_screen.dart';
import 'package:tripapp/trip_home/screens/ledger_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';
import 'package:tripapp/trip_home/widgets/receipt_items.dart';
import 'package:tripapp/trip_home/widgets/today_budget_sheet.dart';

final endpoint = Uri.parse('https://receipt.example.invalid/receipt/recognize');
final connection = ReceiptConnection(endpoint, provider: 'gemini');
Expense receipt() => Expense(
  id: 'receipt',
  icon: '☕',
  place: 'TEST CAFE',
  amount: 5000,
  currency: 'KRW',
  date: DateTime(2026, 10, 4),
  paymentMethod: PaymentMethod.card,
  receiptFingerprint: 'fixture',
  receiptItems: const [
    ReceiptItem(name: 'Americano', quantity: 1, amount: 5000),
  ],
  receiptTaxes: const [
    ReceiptTax(label: '부가세', amount: 455, currency: 'KRW', included: true),
  ],
  receiptAdjustments: const ReceiptAdjustments(
    discount: 500,
    currency: 'KRW',
    details: [
      ReceiptAdjustmentLine(
        label: '서비스료',
        kind: 'surcharge',
        amount: 500,
        currency: 'KRW',
      ),
      ReceiptAdjustmentLine(
        label: '쿠폰 할인',
        kind: 'discount',
        amount: 500,
        currency: 'KRW',
      ),
    ],
  ),
);
Trip travel() => Trip(
  id: 'receipt-trip',
  name: '일본 여행',
  country: countryByIso('JP')!,
  start: DateTime(2027, 5, 1),
  end: DateTime(2027, 5, 8),
  budgetKrw: 100000,
  expenses: [receipt()],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({receiptConsentKey(endpoint): true});
    tripStore.connect(null);
  });
  tearDown(() => tripStore.connect(null));

  test(
    'payment date accepts compact and separated dates but rejects rollover and incomplete input',
    () {
      for (final input in [
        '202691',
        '20260901',
        '2026901',
        '2026-9-1',
        '2026.09.01',
        '2026/9/1',
      ]) {
        expect(parsePaymentDate(input), DateTime(2026, 9, 1));
      }
      expect(parsePaymentDate('2026111'), DateTime(2026, 11, 1));
      expect(parsePaymentDate('2026911'), DateTime(2026, 9, 11));
      expect(parsePaymentDate('20240229'), DateTime(2024, 2, 29));
      for (final input in [
        '20260229',
        '20260931',
        '20261301',
        '20260001',
        '20260900',
        '20269',
        '202609011',
        '00000901',
        '2026-9-31',
        'wrong',
      ]) {
        expect(parsePaymentDate(input), isNull, reason: input);
      }
    },
  );

  testWidgets(
    'date is formatted after short input finishes, without cutting off a two-digit day',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReceiptReviewScreen(
            draft: ReceiptDraft(
              merchant: 'TEST CAFE',
              date: null,
              amount: 5000,
              currency: 'KRW',
              category: '식비',
              warnings: [],
            ),
            image: File('test/fixtures/receipt_en.png').readAsBytesSync(),
          ),
        ),
      );
      final dateField = find.byKey(const ValueKey('receipt-payment-date'));
      await tester.scrollUntilVisible(
        dateField,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(dateField, '202691');
      expect(
        tester.widget<TextFormField>(dateField).controller!.text,
        '202691',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(
        tester.widget<TextFormField>(dateField).controller!.text,
        '2026-09-01',
      );
      await tester.enterText(dateField, '2026911');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(
        tester.widget<TextFormField>(dateField).controller!.text,
        '2026-09-11',
      );
      await tester.enterText(dateField, '20260901');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(dateField).controller!.text,
        '2026-09-01',
      );
      await tester.enterText(dateField, '20260230');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      await tester.pump();
      expect(find.text('올바른 결제일을 확인해주세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retake opens camera and photo selection opens gallery directly; cancellation retains original',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final image =
          'data:image/png;base64,${base64Encode(File('test/fixtures/receipt_en.png').readAsBytesSync())}';
      final sources = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(receiptChannel, (call) async {
            if (call.method == 'close') return null;
            sources.add(call.arguments['gallery'] as bool);
            return sources.length == 1 ? jsonEncode({'image': image}) : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(receiptChannel, null),
      );
      final client = ReceiptClient(
        client: MockClient(
          (request) async => request.method == 'GET'
              ? http.Response(
                  '{"serverUrl":"${endpoint.origin}","provider":"gemini"}',
                  200,
                )
              : http.Response('{}', 500),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReceiptScreen(client: client),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('재촬영'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('재촬영'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
      expect(sources, [false, false, true]);
      expect(find.bySemanticsLabel('촬영한 영수증 원본'), findsOneWidget);
      expect(find.text('영수증 사진 확인'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'confirmed tax-free receipt auto-selects exemption and stores final amount once',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final image =
          'data:image/png;base64,${base64Encode(File('test/fixtures/receipt_tax_free.png').readAsBytesSync())}';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            receiptChannel,
            (call) async =>
                call.method == 'close' ? null : jsonEncode({'image': image}),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(receiptChannel, null),
      );
      final client = ReceiptClient(
        client: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode(
                request.method == 'GET'
                    ? {'serverUrl': endpoint.origin, 'provider': 'gemini'}
                    : {
                        'draft': {
                          'merchant': 'SAMPLE TAX FREE',
                          'date': '2026-10-04',
                          'currency': 'KRW',
                          'amount': 9500,
                          'category': '쇼핑',
                          'warnings': [],
                          'items': [
                            {
                              'name': 'Watch',
                              'quantity': 1,
                              'unit_price': 11000,
                              'amount': 11000,
                            },
                          ],
                          'taxes': [
                            {
                              'label': '부가세',
                              'amount': 1000,
                              'currency': 'KRW',
                              'included': false,
                            },
                          ],
                          'adjustments': {
                            'taxFree': true,
                            'exemptedTax': 1000,
                            'taxFreeBase': null,
                            'discount': 500,
                            'currency': 'KRW',
                          },
                        },
                      },
              ),
            ),
            200,
          ),
        ),
      );
      final t = travel()..expenses.clear();
      tripStore.add(t);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LedgerScreen(trip: t),
        ),
      );
      Navigator.of(tester.element(find.byType(LedgerScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => ExpenseFormScreen(
            trip: t,
            receiptClient: client,
            startWithReceipt: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('영수증 내용 확인'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ReceiptReviewScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인 후 지출 양식에 적용'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('면세 적용'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await tester.ensureVisible(find.text('카드'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('카드'));
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(t.expenses.single.isTaxFree, isTrue);
      expect(t.expenses.single.receiptAdjustments!.exemptedTax, 1000);
      expect(t.expenses.single.receiptAdjustments!.discount, 500);
      expect(t.spentKrw, 9500);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ExpenseDetailScreen(trip: t, expenseId: t.expenses.single.id),
        ),
      );
      await tester.scrollUntilVisible(find.text('최종 금액'), 100);
      expect(find.text('1,000 KRW'), findsOneWidget);
      expect(find.text('500 KRW'), findsOneWidget);
      expect(find.text('최종 금액'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test(
    'translation sends names only, validates results, blocks duplicate calls and revoked consent',
    () async {
      var calls = 0;
      var response = Completer<http.Response>();
      final client = ReceiptClient(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/receipt/translate');
          expect(request.headers['X-Receipt-Consent'], receiptConsentVersion);
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'names': ['Americano'],
            'language': 'ko',
          });
          return response.future;
        }),
      );
      addTearDown(client.close);
      final pending = client.translate(connection, ['Americano'], 'ko');
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        client.translate(connection, ['Americano'], 'ko'),
        throwsA(isA<ReceiptConnectionException>()),
      );
      response.complete(
        http.Response.bytes(utf8.encode('{"names":["아메리카노"]}'), 200),
      );
      expect(await pending, ['아메리카노']);
      for (final invalid in [
        '{"names":[]}',
        '{"names":[null]}',
        '{"names":[""]}',
      ]) {
        response = Completer<http.Response>()
          ..complete(http.Response(invalid, 200));
        await expectLater(
          client.translate(connection, ['Americano'], 'ko'),
          throwsA(isA<ReceiptConnectionException>()),
        );
      }
      expect(calls, 4);
      await (await SharedPreferences.getInstance()).setBool(
        receiptConsentKey(endpoint),
        false,
      );
      await expectLater(
        client.translate(connection, ['Americano'], 'ko'),
        throwsA(isA<ReceiptConnectionException>()),
      );
      expect(calls, 4);
    },
  );

  for (final width in [320.0, 440.0]) {
    testWidgets(
      'detail preserves original, toggles cached translations and displays tax at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final t = travel();
        var posts = 0;
        final client = ReceiptClient(
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(
                '{"serverUrl":"${endpoint.origin}","provider":"gemini"}',
                200,
              );
            }
            posts++;
            final language = jsonDecode(request.body)['language'];
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'names': [language == 'ko' ? '아메리카노' : 'Americano coffee'],
                }),
              ),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: ExpenseDetailScreen(
              trip: t,
              expenseId: 'receipt',
              receiptClient: client,
            ),
          ),
        );
        await tester.tap(find.text('품목 상세 (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Americano'), findsOneWidget);
        expect(posts, 0);
        await tester.tap(find.text('한국어'));
        await tester.pumpAndSettle();
        expect(find.text('아메리카노'), findsOneWidget);
        expect(find.text('수량 1'), findsOneWidget);
        expect(find.text('5,000 KRW'), findsOneWidget);
        await tester.tap(find.text('한국어'));
        await tester.pump();
        expect(find.text('Americano'), findsOneWidget);
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(find.text('Americano coffee'), findsOneWidget);
        await tester.tap(find.text('한국어'));
        await tester.pumpAndSettle();
        expect(
          posts,
          2,
          reason: 'Already translated language reuses in-screen result',
        );
        expect(t.expenses.single.receiptItems.single.name, 'Americano');
        expect(t.spentKrw, 5000);
        await tester.scrollUntilVisible(find.text('부가세'), 150);
        expect(find.text('455 KRW\n결제금액에 포함'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('서비스료 · 추가금'), 100);
        expect(find.text('+500 KRW'), findsOneWidget);
        expect(find.text('쿠폰 할인 · 할인'), findsOneWidget);
        expect(find.text('−500 KRW'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'translation failure and edited names keep originals without stale cached translation',
    (tester) async {
      var fail = true, calls = 0;
      Future<List<String>?> translate(String language) async {
        calls++;
        if (fail) throw const ReceiptConnectionException('번역 연결 오류');
        return ['아메리카노'];
      }

      Widget view(String name) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ReceiptItems(
            items: [ReceiptItem(name: name, quantity: 1, amount: 5000)],
            currency: 'KRW',
            onTranslate: translate,
          ),
        ),
      );
      await tester.pumpWidget(view('Americano'));
      await tester.tap(find.text('품목 상세 (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();
      expect(find.text('Americano'), findsOneWidget);
      expect(find.text('번역 연결 오류'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();
      expect(find.text('아메리카노'), findsOneWidget);
      await tester.pumpWidget(view('Milk'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('아메리카노'), findsNothing);
      expect(calls, 2);
    },
  );

  testWidgets(
    'existing receipts ask consent only when translation requested; cancelling sends no names',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var posts = 0;
      final client = ReceiptClient(
        client: MockClient((request) async {
          if (request.method == 'POST') posts++;
          return http.Response(
            '{"serverUrl":"${endpoint.origin}","provider":"gemini"}',
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ExpenseDetailScreen(
            trip: travel(),
            expenseId: 'receipt',
            receiptClient: client,
          ),
        ),
      );
      expect(find.text('영수증 인식 안내'), findsNothing);
      await tester.tap(find.text('품목 상세 (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();
      expect(find.text('영수증 인식 안내'), findsOneWidget);
      Navigator.of(tester.element(find.text('영수증 인식 안내'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Americano'), findsOneWidget);
      expect(posts, 0);
    },
  );

  testWidgets(
    'tax metadata survives Firestore round-trip and expense edit without inflating total',
    (tester) async {
      final t = travel();
      final repo = FirestoreTripRepository(
        uid: 'receipt-tax-fixture',
        db: FakeFirebaseFirestore(),
      );
      await repo.saveTrip(t);
      await repo.saveExpense(t.id, t.expenses.single);
      final restored = (await repo.watchExpenses(t.id).first).single;
      expect(restored.receiptTaxes.single.amount, 455);
      expect(restored.receiptAdjustments!.details.first.label, '서비스료');
      t.expenses
        ..clear()
        ..add(restored);
      tripStore.add(t);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ExpenseDetailScreen(trip: t, expenseId: restored.id),
        ),
      );
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(t.expenses.single.receiptTaxes.single.included, isTrue);
      expect(t.spentKrw, 5000);
      expect(t.expenses.single.receiptItems.single.name, 'Americano');
      expect(
        t.expenses.single.receiptAdjustments!.details.last.isDiscount,
        isTrue,
      );
    },
  );

  testWidgets(
    'ledger summary opens the same today budget and trip edit sheets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final t = travel();
      tripStore.add(t);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: TripHomeScreen(trip: t),
        ),
      );
      final homeTop = tester.getTopLeft(
        find.byKey(const ValueKey('home-budget-card')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: LedgerScreen(trip: t),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('ledger-budget-card'))),
        homeTop,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('ledger-list-heading'))).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const ValueKey('ledger-filter-menu')))
              .dy,
        ),
      );
      await tester.tap(find.byTooltip('오늘 예산'));
      await tester.pumpAndSettle();
      expect(find.byType(TodayBudgetSheet), findsOneWidget);
      expect(
        tester.widget<TodayBudgetSheet>(find.byType(TodayBudgetSheet)).trip,
        same(t),
      );
      Navigator.of(tester.element(find.byType(TodayBudgetSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('여행 편집'));
      await tester.pumpAndSettle();
      expect(find.text('여행 편집'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
