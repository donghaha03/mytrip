// [OCR] 영수증 OCR 기능 (feature/receipt-ocr)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart';
import 'package:tripapp/ledger_page.dart';
import 'package:tripapp/receipt_scan_page.dart';

/// 1×1 PNG. 개인정보 없는 합성 이미지.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

final now = DateTime(2026, 11, 24, 15, 30);

Receipt read(Map<String, dynamic> draft) => Receipt.fromJson(draft, now: now);

http.Response json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

final trip = Trip(
  id: 't1',
  name: '도쿄',
  budget: 1000000,
  currency: 'JPY',
  start: DateTime(2026, 11, 20),
  end: DateTime(2026, 11, 27),
);

void main() {
  group('Receipt.fromJson', () {
    test('서버 응답을 지출 입력값으로 옮긴다', () {
      final receipt = read({
        'merchant': '  SAMPLE CAFE  ',
        'date': '2026-11-22',
        'currency': 'JPY',
        'amount': 1280,
        'category': '식비',
        'items': <Object>[],
        'warnings': <Object>[],
      });
      expect(receipt.place, 'SAMPLE CAFE');
      expect(receipt.amount, 1280.0);
      expect(receipt.currency, 'JPY');
      expect(receipt.category, '식비');
      expect(receipt.paymentMethod, 'cash');
      // 날짜는 영수증 날짜, 시각은 지금
      expect(receipt.date, DateTime(2026, 11, 22, 15, 30));
    });

    test('카테고리는 앱의 여섯 가지 중 하나로, 아니면 기타', () {
      for (final category in categoryIcons.keys) {
        expect(read({'category': category}).category, category);
      }
      expect(read({'category': '의료'}).category, '기타');
      expect(read({'category': 3}).category, '기타');
      expect(read({}).category, '기타');
    });

    test('결제수단은 카드 결제 근거가 있을 때만 card', () {
      expect(read({'paymentMethod': 'card'}).paymentMethod, 'card');
      expect(
        read({
          'adjustments': {
            'details': [
              {'label': '카드 수수료', 'kind': 'surcharge', 'amount': 30},
            ],
          },
        }).paymentMethod,
        'card',
      );
      expect(read({'paymentMethod': 'bitcoin'}).paymentMethod, 'cash');
      expect(
        read({
          'adjustments': {
            'details': [
              {'label': '쿠폰 할인', 'kind': 'discount', 'amount': 500},
            ],
          },
        }).paymentMethod,
        'cash',
      );
      expect(read({'adjustments': 'x'}).paymentMethod, 'cash');
    });

    test('통화는 앱이 환율을 아는 통화만 남기고, 아니면 null(여행 통화 사용)', () {
      expect(read({'currency': 'KRW'}).currency, 'KRW');
      for (final currency in currencies) {
        expect(read({'currency': currency}).currency, currency);
      }
      expect(read({'currency': 'GBP'}).currency, isNull);
      expect(read({'currency': 'usd'}).currency, isNull);
      expect(read({'currency': 840}).currency, isNull);
      expect(read({}).currency, isNull);
    });

    test('지원하지 않는 통화(CAD)면 금액을 비우고 원래 통화를 남긴다', () {
      final receipt = read({
        'merchant': 'SAMPLE DINER',
        'date': '2026-11-22',
        'currency': 'CAD',
        'amount': 16.85,
        'category': '식비',
        'paymentMethod': 'card',
      });
      // 16.85 CAD가 여행 통화 금액(예: 16.85엔)으로 저장되면 안 된다.
      expect(receipt.amount, isNull);
      expect(receipt.currency, isNull);
      expect(receipt.unsupportedCurrency, 'CAD');
      // 나머지는 그대로 채운다.
      expect(receipt.place, 'SAMPLE DINER');
      expect(receipt.date, DateTime(2026, 11, 22, 15, 30));
      expect(receipt.category, '식비');
      expect(receipt.paymentMethod, 'card');
    });

    test('통화를 못 읽었으면(null·빈 값) 여행 통화로 보고 금액을 그대로 둔다', () {
      for (final currency in [null, '', '  ', 840]) {
        final receipt = read({'currency': currency, 'amount': 16.85});
        expect(receipt.amount, 16.85, reason: '$currency');
        expect(receipt.currency, isNull, reason: '$currency');
        expect(receipt.unsupportedCurrency, isNull, reason: '$currency');
      }
      // 지원하는 통화는 금액과 통화를 모두 남긴다.
      final usd = read({'currency': 'USD', 'amount': 16.85});
      expect(
        (usd.amount, usd.currency, usd.unsupportedCurrency),
        (16.85, 'USD', null),
      );
    });

    test('날짜: 없거나 잘못됐거나 미래면 null(저장 시각 사용)', () {
      expect(read({'date': '2026-11-24'}).date, DateTime(2026, 11, 24, 15, 30));
      expect(read({'date': '2026-11-25'}).date, isNull); // 미래
      expect(read({'date': '2026-02-30'}).date, isNull); // 없는 날짜
      expect(read({'date': '2026-13-01'}).date, isNull);
      expect(read({'date': '11/22/2026'}).date, isNull);
      expect(read({'date': 20261122}).date, isNull);
      expect(read({}).date, isNull);
    });

    test('빈 값·이상한 값은 버린다', () {
      final empty = read({});
      expect(empty.place, '');
      expect(empty.amount, isNull);

      expect(read({'merchant': 42}).place, '');
      expect(read({'merchant': 'a' * 80}).place.length, 50);
      expect(read({'amount': 0}).amount, isNull);
      expect(read({'amount': -500}).amount, isNull);
      expect(read({'amount': '1280'}).amount, isNull);
      expect(read({'amount': double.nan}).amount, isNull);
      expect(read({'amount': double.infinity}).amount, isNull);
      expect(read({'amount': 12.5}).amount, 12.5);
    });
  });

  group('ReceiptApi.scan', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => ReceiptApi.client = http.Client());
    });

    test('동의 헤더와 사진만 보내고, 응답을 Receipt로 돌려준다', () async {
      late http.Request sent;
      ReceiptApi.client = MockClient((request) async {
        sent = request;
        return json({
          'draft': {'merchant': 'SAMPLE CAFE', 'amount': 12000},
        });
      });
      expect(await ReceiptApi.hasConsent(), isFalse);
      await ReceiptApi.saveConsent();
      expect(await ReceiptApi.hasConsent(), isTrue);

      final receipt = await ReceiptApi.scan(png);
      expect(receipt.place, 'SAMPLE CAFE');
      expect(receipt.amount, 12000.0);
      expect(sent.url.path, '/receipt/recognize');
      expect(sent.headers['X-Receipt-Consent'], 'claude-haiku-v1');
      expect(sent.headers.keys, isNot(contains('Authorization')));
      expect((jsonDecode(sent.body) as Map).keys, [
        'image',
      ], reason: '사진 말고는 보내지 않는다');
    });

    test('지원하지 않는 통화뿐이어도 인식 실패로 보지 않는다', () async {
      ReceiptApi.client = MockClient(
        (_) async => json({
          'draft': {'currency': 'CAD', 'amount': 16.85},
        }),
      );
      await ReceiptApi.saveConsent();
      final receipt = await ReceiptApi.scan(png);
      expect(receipt.amount, isNull);
      expect(receipt.unsupportedCurrency, 'CAD');
    });

    test('실패는 사용자에게 보여줄 문구가 담긴 ApiException', () async {
      Future<String> message(Future<http.Response> Function() respond) async {
        ReceiptApi.client = MockClient((_) => respond());
        try {
          await ReceiptApi.scan(png);
        } on ApiException catch (e) {
          return e.message;
        }
        return fail('ApiException이 나와야 한다');
      }

      // 동의 전에는 서버로 보내지 않는다.
      expect(await message(() async => fail('보내면 안 된다')), contains('동의'));
      await ReceiptApi.saveConsent();

      expect(await message(() async => json({}, 400)), contains('사진을 읽지 못했어요'));
      expect(await message(() async => json({}, 401)), contains('동의'));
      expect(await message(() async => json({}, 403)), contains('이 주소'));
      expect(await message(() async => json({}, 429)), contains('한도'));
      expect(await message(() async => json({}, 500)), contains('인식하지 못했어요'));
      expect(
        await message(() async => throw http.ClientException('offline')),
        contains('네트워크'),
      );
      // 형식이 다른 응답, 아무것도 못 읽은 응답
      expect(
        await message(() async => json({'draft': 1})),
        contains('읽지 못했어요'),
      );
      expect(
        await message(() async => json({'draft': <String, Object>{}})),
        contains('읽지 못했어요'),
      );

      // 사진이 아닌 파일은 보내지 않는다.
      ReceiptApi.client = MockClient((_) async => fail('보내면 안 된다'));
      await expectLater(
        ReceiptApi.scan(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('지출 추가 시트', () {
    Future<void> open(WidgetTester tester, Widget sheet) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: sheet)));

    String field(WidgetTester tester, int index) => tester
        .widget<TextFormField>(find.byType(TextFormField).at(index))
        .controller!
        .text;

    testWidgets('초기값 없이 열면 기존과 같다 (빈 칸, 첫 카테고리, 현금, 여행 통화)', (tester) async {
      await open(tester, AddExpenseSheet(trip: trip));
      expect(field(tester, 0), '');
      expect(field(tester, 1), '');
      expect(find.text(categoryIcons.keys.first), findsOneWidget);
      expect(find.text('현금'), findsOneWidget);
      expect(find.text('금액은 JPY 기준으로 입력하세요.'), findsOneWidget);
      expect(find.text('금액 (JPY)'), findsOneWidget);
      expect(find.textContaining('영수증 날짜'), findsNothing);
    });

    testWidgets('영수증 값으로 채워서 연다', (tester) async {
      await open(
        tester,
        AddExpenseSheet(
          trip: trip,
          initialPlace: 'SAMPLE CAFE',
          initialAmount: 12000,
          initialCategory: '쇼핑',
          initialPaymentMethod: 'card',
          initialDate: DateTime(2026, 11, 22, 15, 30),
          initialCurrency: 'KRW',
        ),
      );
      expect(field(tester, 0), 'SAMPLE CAFE');
      expect(field(tester, 1), '12000');
      expect(find.text('쇼핑'), findsOneWidget);
      expect(find.text('카드'), findsOneWidget);
      // 여행 통화(JPY)와 다른 영수증 통화가 보인다.
      expect(find.text('금액은 KRW 기준으로 입력하세요.'), findsOneWidget);
      expect(find.text('금액 (KRW)'), findsOneWidget);
      expect(find.textContaining('영수증 날짜 2026.11.22'), findsOneWidget);
    });

    testWidgets('지원하지 않는 통화 영수증: 금액은 빈칸, 안내를 시트에 보여준다', (tester) async {
      final receipt = read({
        'merchant': 'SAMPLE DINER',
        'currency': 'CAD',
        'amount': 16.85,
      });
      await open(
        tester,
        AddExpenseSheet(
          trip: trip,
          initialPlace: receipt.place,
          initialAmount: receipt.amount,
          initialCurrency: receipt.currency,
          initialNote: '지원하지 않는 통화(CAD)라 금액을 직접 입력해주세요.',
        ),
      );
      expect(field(tester, 0), 'SAMPLE DINER');
      expect(field(tester, 1), '');
      expect(find.text('금액 (JPY)'), findsOneWidget);
      expect(find.textContaining('지원하지 않는 통화(CAD)'), findsOneWidget);
    });

    testWidgets('소수 금액과 잘못된 초기값', (tester) async {
      await open(
        tester,
        AddExpenseSheet(
          trip: trip,
          initialAmount: 12.5,
          initialCategory: '의료',
          initialPaymentMethod: 'bitcoin',
        ),
      );
      expect(field(tester, 1), '12.5');
      expect(find.text(categoryIcons.keys.first), findsOneWidget);
      expect(find.text('현금'), findsOneWidget);
    });
  });

  testWidgets('촬영 화면: 처음엔 동의 → 카메라가 없으면 앨범 → 인식 결과로 닫힌다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ReceiptApi.client = MockClient(
      (_) async => json({
        'draft': {'merchant': 'SAMPLE CAFE', 'amount': 12000, 'category': '식비'},
      }),
    );
    ReceiptScanPage.pickForTest = () async => png;
    // 카메라가 한 대도 없는 기기
    const cameraChannel = MethodChannel('plugins.flutter.io/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      cameraChannel,
      (call) async => <Object>[],
    );
    addTearDown(() {
      ReceiptApi.client = http.Client();
      ReceiptScanPage.pickForTest = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        cameraChannel,
        null,
      );
    });

    Receipt? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.push<Receipt>(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptScanPage()),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 동의 전에는 카메라도 서버도 쓰지 않는다.
    expect(find.text('동의하고 계속'), findsOneWidget);
    expect(find.text('촬영'), findsNothing);
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    expect(await ReceiptApi.hasConsent(), isTrue);

    // 카메라가 없으면 이유를 보여주고 앨범으로 이어준다.
    expect(find.textContaining('사용할 수 있는 카메라가 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.tap(find.text('앨범에서 선택'));
    await tester.pumpAndSettle();

    expect(find.text('재촬영'), findsOneWidget);
    await tester.tap(find.text('이 사진으로 인식'));
    await tester.pumpAndSettle();

    expect(find.byType(ReceiptScanPage), findsNothing);
    expect(result?.place, 'SAMPLE CAFE');
    expect(result?.amount, 12000.0);
    expect(result?.category, '식비');
    expect(tester.takeException(), isNull);
  });
}
