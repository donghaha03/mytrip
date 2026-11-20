import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/OCR/api/ocr_api.dart';
import 'package:tripapp/OCR/ocr_screen.dart';
import 'package:tripapp/OCR/receipt_expense_screen.dart';
import 'package:tripapp/api/api.dart' show Trip;

final now = DateTime(2026, 11, 20, 14, 30);

final trip = Trip(
  id: 'trip-1',
  name: '도쿄 여행',
  budget: 1000000,
  currency: 'JPY',
  start: DateTime(2026, 11, 18),
  end: DateTime(2026, 11, 22),
);

ExpenseDraft draftOf(OcrReceipt receipt) =>
    ExpenseDraft.fromReceipt(receipt, tripCurrency: 'JPY', now: now);

/// 1×1 PNG. 개인정보 없는 합성 이미지.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  group('영수증 → 지출 초안', () {
    test('가맹점·금액·통화·날짜·카테고리를 그대로 옮긴다', () {
      final draft = draftOf(
        OcrReceipt(
          merchant: 'SAMPLE CAFE',
          date: DateTime(2026, 11, 19),
          currency: 'JPY',
          amount: 1200,
          category: '식비',
        ),
      );
      expect(draft.place, 'SAMPLE CAFE');
      expect(draft.amount, 1200);
      expect(draft.currency, 'JPY');
      expect(draft.category, '식비');
      // 영수증에는 날짜만 있으므로 시각은 지금 시각을 쓴다.
      expect(draft.date, DateTime(2026, 11, 19, 14, 30));
      expect(draft.notes, isEmpty);
    });

    test('여행 통화와 달라도 앱이 아는 통화면 영수증 통화로 둔다', () {
      for (final currency in ['KRW', 'USD']) {
        final draft = draftOf(OcrReceipt(currency: currency, amount: 5));
        expect(draft.currency, currency);
        expect(draft.notes.where((note) => note.contains('통화')), isEmpty);
      }
    });

    test('모르는 통화나 읽지 못한 통화는 여행 통화로 채우고 알려준다', () {
      final unknown = draftOf(
        OcrReceipt(currency: 'GBP', amount: 5, date: DateTime(2026, 11, 19)),
      );
      expect(unknown.currency, 'JPY');
      expect(unknown.notes.single, contains('GBP'));
      final missing = draftOf(const OcrReceipt(amount: 5));
      expect(missing.currency, 'JPY');
      expect(missing.notes, contains(contains('통화를 읽지 못해')));
    });

    test('금액이 없거나 0 이하면 비워 두고 알려준다', () {
      for (final amount in <double?>[null, 0, -100]) {
        final draft = draftOf(OcrReceipt(currency: 'JPY', amount: amount));
        expect(draft.amount, isNull, reason: '$amount');
        expect(draft.notes, contains(contains('금액')));
      }
    });

    test('날짜가 없거나 미래면 지금으로 채우고 알려준다', () {
      final missing = draftOf(const OcrReceipt(currency: 'JPY', amount: 5));
      expect(missing.date, now);
      expect(missing.notes, contains(contains('날짜를 읽지 못해')));
      final future = draftOf(
        OcrReceipt(currency: 'JPY', amount: 5, date: DateTime(2027, 1, 1)),
      );
      expect(future.date, now);
      expect(future.notes, contains(contains('미래')));
      // 오늘 영수증은 미래로 보지 않는다.
      final today = draftOf(
        OcrReceipt(currency: 'JPY', amount: 5, date: DateTime(2026, 11, 20)),
      );
      expect(today.date, now);
      expect(today.notes, isEmpty);
    });

    test('가맹점 이름은 50자까지만, 없으면 빈칸. 인식 경고는 그대로 전달한다', () {
      final long = draftOf(
        OcrReceipt(merchant: 'A' * 80, currency: 'JPY', amount: 5),
      );
      expect(long.place.length, 50);
      final draft = draftOf(
        OcrReceipt(
          currency: 'JPY',
          amount: 5,
          date: DateTime(2026, 11, 19),
          warnings: const ['총액 확인 필요'],
        ),
      );
      expect(draft.place, '');
      expect(draft.notes, ['총액 확인 필요']);
    });
  });

  group('화면', () {
    testWidgets('영수증 OCR 버튼 → 인식 → 내용 확인 화면으로 이어지고 값이 채워진다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'receipt_consent:$ocrConsentVersion:https://receipt.example.invalid':
            true,
      });
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      OcrApi.server = Uri.parse('https://receipt.example.invalid');
      OcrApi.pickPhotoForTest = (_) async => png;
      addTearDown(() => OcrApi.pickPhotoForTest = null);
      OcrApi.client = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'draft': {
                'merchant': 'SAMPLE CAFE',
                'date': '2026-10-04',
                'currency': 'USD',
                'amount': 12.5,
                'category': '식비',
                'items': <Object>[],
                'warnings': <Object>[],
              },
            }),
          ),
          200,
        ),
      );

      // 장부의 "영수증 OCR" 버튼과 같은 방식으로 연다.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => openReceiptOcr(context, trip),
                child: const Text('영수증 OCR'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('영수증 OCR'));
      await tester.pumpAndSettle();
      expect(find.byType(OcrScreen), findsOneWidget);
      // 인식 전에는 지출 추가 버튼이 없다.
      expect(find.byKey(const ValueKey('ocr-add-expense')), findsNothing);

      await tester.tap(find.text('사진 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ocr-recognize')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ocr-add-expense')));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptExpenseScreen), findsOneWidget);
      expect(find.text('도쿄 여행에 추가돼요. 틀린 곳은 고쳐주세요.'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'SAMPLE CAFE'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '12.5'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget); // 영수증 통화 그대로
      expect(find.text('2026.10.04'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('빈 값은 저장하지 않고, 저장 실패(환율 없음)는 화면에 문구로 보인다', (tester) async {
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ReceiptExpenseScreen(
            trip: trip,
            draft: draftOf(const OcrReceipt(currency: 'JPY')),
          ),
        ),
      );
      // 읽지 못한 금액·가맹점은 비어 있고, 이유를 알려준다.
      expect(find.textContaining('결제 금액을 읽지 못했어요'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('expense-save')));
      await tester.pumpAndSettle();
      expect(find.text('사용처를 입력해 주세요.'), findsOneWidget);
      expect(find.text('올바른 금액을 입력해 주세요.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('expense-place')),
        '편의점',
      );
      await tester.enterText(
        find.byKey(const ValueKey('expense-amount')),
        '1,500',
      );
      // 테스트에서는 환율을 불러온 적이 없다 = rates/current가 없는 Firebase와 같은 상태.
      await tester.tap(find.byKey(const ValueKey('expense-save')));
      await tester.pumpAndSettle();
      expect(find.text('환율 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요'), findsOneWidget);
      // 실패해도 화면과 입력값은 그대로다.
      expect(find.byType(ReceiptExpenseScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '편의점'), findsOneWidget);
    });
  });
}
