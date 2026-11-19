import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/OCR/consent_screen.dart';
import 'package:tripapp/OCR/main_ocr.dart';
import 'package:tripapp/OCR/ocr_screen.dart';
import 'package:tripapp/OCR/receipt_result.dart';
import 'package:tripapp/OCR/receipt_service.dart';
import 'package:tripapp/api/api.dart' show ApiException;

/// 1×1 PNG. 개인정보 없는 합성 이미지.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Map<String, dynamic> draft() => {
  'merchant': 'SAMPLE CAFE',
  'date': '2026-10-04',
  'currency': 'KRW',
  'amount': 12000,
  'category': '식비',
  'taxes': [
    {'label': '부가세', 'amount': 909, 'currency': 'KRW', 'included': true},
  ],
  'adjustments': {
    'taxFree': null,
    'exemptedTax': null,
    'taxFreeBase': null,
    'discount': 1500,
    'currency': 'KRW',
    'details': [
      {'label': '서비스료', 'kind': 'surcharge', 'amount': 1000, 'currency': 'KRW'},
      {'label': '쿠폰 할인', 'kind': 'discount', 'amount': 1500, 'currency': 'KRW'},
    ],
  },
  'items': [
    {'name': 'Americano', 'quantity': 2, 'unit_price': 5000, 'amount': 10000},
    {'name': '牛乳', 'quantity': 1, 'unit_price': 2500, 'amount': 2500},
  ],
  'warnings': ['날짜 확인 필요'],
};

const server = 'https://receipt.example.invalid';
const consentKey = 'receipt_consent:$ocrConsentVersion:$server';

OcrService service(MockClient client) =>
    OcrService(client: client, server: Uri.parse(server));

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({consentKey: true}));

  group('인식 결과', () {
    test('상호·날짜·총액·품목·세금·할인을 읽는다', () {
      final receipt = OcrReceipt.fromDraft(draft());
      expect(receipt.merchant, 'SAMPLE CAFE');
      expect(receipt.date, DateTime(2026, 10, 4));
      expect(receipt.currency, 'KRW');
      expect(receipt.amount, 12000);
      expect(receipt.category, '식비');
      expect(receipt.items.map((i) => (i.name, i.quantity, i.amount)), [
        ('Americano', 2, 10000.0),
        ('牛乳', 1, 2500.0),
      ]);
      expect(receipt.taxes.single.label, '부가세');
      expect(receipt.taxes.single.amount, 909);
      expect(receipt.taxes.single.included, isTrue);
      expect(receipt.discount, 1500);
      expect(receipt.taxFree, isNull);
      expect(
        receipt.adjustments.map((a) => (a.label, a.isDiscount, a.amount)),
        [('서비스료', false, 1000.0), ('쿠폰 할인', true, 1500.0)],
      );
      expect(receipt.warnings, ['날짜 확인 필요']);
    });

    test('면세 정보와 비어 있는 값을 그대로 둔다', () {
      final receipt = OcrReceipt.fromDraft({
        ...draft(),
        'merchant': null,
        'date': null,
        'amount': null,
        'adjustments': {
          'taxFree': true,
          'exemptedTax': 1000,
          'taxFreeBase': 10000,
          'discount': null,
          'currency': 'JPY',
          'details': <Object>[],
        },
      });
      expect(receipt.merchant, isNull);
      expect(receipt.date, isNull);
      expect(receipt.amount, isNull);
      expect(receipt.taxFree, isTrue);
      expect(receipt.exemptedTax, 1000);
      expect(receipt.taxFreeBase, 10000);
      expect(receipt.adjustmentCurrency, 'JPY');
    });

    test('세금·할인·카테고리가 없는 예전 형식도 읽는다', () {
      final old = draft()
        ..remove('taxes')
        ..remove('adjustments')
        ..remove('category');
      final receipt = OcrReceipt.fromDraft(old);
      expect(receipt.category, '기타');
      expect(receipt.taxes, isEmpty);
      expect(receipt.adjustments, isEmpty);
    });

    test('계약과 다른 응답은 결과가 되지 않는다', () {
      final item = (draft()['items'] as List).first as Map<String, dynamic>;
      final adjustments = draft()['adjustments'] as Map<String, dynamic>;
      for (final bad in <Object?>[
        null,
        'text',
        {...draft(), 'date': '2026-02-30'},
        {...draft(), 'date': '10/04'},
        {...draft(), 'amount': '12000'},
        {...draft(), 'amount': double.infinity},
        {...draft(), 'currency': 'won'},
        {...draft(), 'category': '없는 카테고리'},
        {...draft(), 'items': 'none'},
        {
          ...draft(),
          'items': ['Americano'],
        },
        {
          ...draft(),
          'items': [
            {...item, 'quantity': 1.5},
          ],
        },
        {
          ...draft(),
          'taxes': [
            {'label': '기타세', 'amount': 1, 'currency': 'KRW', 'included': null},
          ],
        },
        {
          ...draft(),
          'adjustments': {...adjustments, 'discount': -1},
        },
        {
          ...draft(),
          'adjustments': {
            ...adjustments,
            'details': [
              {'label': '행사', 'kind': 'offer', 'amount': 1, 'currency': 'KRW'},
            ],
          },
        },
        {
          ...draft(),
          'warnings': [1],
        },
      ]) {
        expect(
          () => OcrReceipt.fromDraft(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('서버 호출', () {
    test('사진 형식을 바이트로 확인한다', () {
      expect(receiptDataUrl(png), startsWith('data:image/png;base64,iVBOR'));
      expect(
        receiptDataUrl(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])),
        startsWith('data:image/jpeg;base64,'),
      );
      expect(
        receiptDataUrl(Uint8List.fromList(utf8.encode('RIFF0000WEBPVP8 '))),
        startsWith('data:image/webp;base64,'),
      );
      expect(receiptDataUrl(Uint8List.fromList(utf8.encode('GIF89a'))), isNull);
      expect(receiptDataUrl(Uint8List(0)), isNull);
    });

    test('동의 버전과 사진만 보내고 접속 코드는 쓰지 않는다', () async {
      late http.Request sent;
      final ocr = service(
        MockClient((request) async {
          sent = request;
          return json({'draft': draft(), 'model': 'm', 'provider': 'claude'});
        }),
      );
      final receipt = await ocr.recognize(png);
      expect(receipt.merchant, 'SAMPLE CAFE');
      expect(sent.url.toString(), '$server/receipt/recognize');
      expect(sent.headers['X-Receipt-Consent'], 'claude-haiku-v1');
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(sent.body), {'image': receiptDataUrl(png)});
    });

    test('동의하지 않았거나 예전 동의만 있으면 아무것도 보내지 않는다', () async {
      var calls = 0;
      final ocr = service(
        MockClient((_) async {
          calls++;
          return json({'draft': draft()});
        }),
      );
      for (final stored in <Map<String, Object>>[
        {},
        {consentKey: false},
        // 다른 제공자에 했던 동의는 인정하지 않는다.
        {'receipt_consent:gemini-free-v2:$server': true},
      ]) {
        SharedPreferences.setMockInitialValues(stored);
        await expectLater(ocr.recognize(png), throwsA(isA<ApiException>()));
        await expectLater(
          ocr.translate(['Americano'], 'ko'),
          throwsA(isA<ApiException>()),
        );
      }
      expect(calls, 0);
      await ocr.setConsent(true);
      expect(await ocr.consent(), isTrue);
      expect((await ocr.recognize(png)).amount, 12000);
      expect(calls, 1);
    });

    test('서버 오류와 틀린 결과는 안내 문구가 되고 원문 오류는 숨긴다', () async {
      for (final (status, expected) in [
        (401, '동의'),
        (403, '주소'),
        (413, '너무 커요'),
        (429, '한도'),
        (502, '인식하지 못했어요'),
        (503, '준비'),
      ]) {
        final ocr = service(
          MockClient((_) async => json({'error': 'provider-secret'}, status)),
        );
        await expectLater(
          ocr.recognize(png),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', contains(expected))
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('provider-secret')),
                ),
          ),
        );
      }
      for (final body in <Object>[
        {'draft': <String, Object>{}},
        {
          'draft': {...draft(), 'date': '2026-02-30'},
        },
        <Object>[],
      ]) {
        final ocr = service(MockClient((_) async => json(body)));
        await expectLater(ocr.recognize(png), throwsA(isA<ApiException>()));
      }
      final offline = service(MockClient((_) async => throw Exception('down')));
      await expectLater(offline.recognize(png), throwsA(isA<ApiException>()));
      final gif = service(MockClient((_) async => fail('must not send')));
      await expectLater(
        gif.recognize(Uint8List.fromList(utf8.encode('GIF89a'))),
        throwsA(isA<ApiException>()),
      );
    });

    test('번역은 품목 이름만 보내고 개수가 맞아야 받는다', () async {
      var reply = <String>['아메리카노', '우유'];
      late http.Request sent;
      final ocr = service(
        MockClient((request) async {
          sent = request;
          return json({'names': reply});
        }),
      );
      expect(await ocr.translate(['Americano', '牛乳'], 'ko'), reply);
      expect(sent.url.path, '/receipt/translate');
      expect(jsonDecode(sent.body), {
        'names': ['Americano', '牛乳'],
        'language': 'ko',
      });
      reply = ['한 줄만'];
      await expectLater(
        ocr.translate(['Americano', '牛乳'], 'ko'),
        throwsA(isA<ApiException>()),
      );
      for (final bad in [
        <String>[],
        [''],
        ['a' * 101],
      ]) {
        await expectLater(
          ocr.translate(bad, 'ko'),
          throwsA(isA<ApiException>()),
        );
      }
      await expectLater(
        ocr.translate(['Americano'], 'ja'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('화면', () {
    testWidgets('동의 화면은 Anthropic 기준으로 안내하고 체크해야 동의할 수 있다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ocr = service(MockClient((_) async => fail('must not send')));
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await Navigator.of(context)
                  .push<bool>(
                    MaterialPageRoute(
                      builder: (_) => OcrConsentScreen(service: ocr),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Anthropic의 Claude'), findsOneWidget);
      for (final gone in ['Google', 'Gemini', '무료']) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      await tester.tap(find.text('전송·보관·이용 한도 안내'));
      await tester.pumpAndSettle();
      expect(find.textContaining('하루 200건'), findsOneWidget);
      expect(find.text(ocrTermsUrl), findsOneWidget);

      final accept = find.widgetWithText(FilledButton, '동의하고 시작하기');
      await tester.ensureVisible(accept);
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(await ocr.consent(), isTrue);
    });

    testWidgets('사진 선택 → 동의 → 인식 결과 → 품목 번역', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      final ocr = service(
        MockClient((request) async {
          paths.add(request.url.path);
          return request.url.path == '/receipt/translate'
              ? json({
                  'names': ['아메리카노', '우유'],
                })
              : json({'draft': draft()});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OcrScreen(service: ocr, pickImage: (_) async => png),
        ),
      );
      expect(find.byKey(const ValueKey('ocr-recognize')), findsNothing);
      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ocr-recognize')));
      await tester.pumpAndSettle();

      // 처음에는 동의 화면이 먼저 뜨고, 그 전에는 아무것도 보내지 않는다.
      expect(find.byType(OcrConsentScreen), findsOneWidget);
      expect(paths, isEmpty);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '동의하고 시작하기'));
      await tester.pumpAndSettle();

      expect(paths, ['/receipt/recognize']);
      expect(find.text('SAMPLE CAFE'), findsOneWidget);
      expect(find.text('2026.10.04 · 식비'), findsOneWidget);
      expect(find.text('12,000 KRW'), findsOneWidget);
      expect(find.text('Americano × 2'), findsOneWidget);
      expect(find.text('부가세 (결제금액에 포함)'), findsOneWidget);
      expect(find.text('할인 · 쿠폰 할인'), findsOneWidget);
      expect(find.text('추가금 · 서비스료'), findsOneWidget);
      expect(find.text('확인: 날짜 확인 필요'), findsOneWidget);

      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();
      expect(paths.last, '/receipt/translate');
      expect(find.text('아메리카노 × 2'), findsOneWidget);
      await tester.tap(find.text('원문'));
      await tester.pumpAndSettle();
      expect(find.text('Americano × 2'), findsOneWidget);
      // 같은 언어는 다시 요청하지 않는다.
      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();
      expect(paths.length, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('단독 앱은 Firebase 없이 첫 화면을 띄운다', (tester) async {
      await tester.pumpWidget(const OcrApp());
      expect(find.text('영수증 인식'), findsOneWidget);
      expect(find.text('사진 촬영'), findsOneWidget);
      expect(find.text('사진 선택'), findsOneWidget);
    });
  });
}
