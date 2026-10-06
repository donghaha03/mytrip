import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/trip_home/models/receipt_item.dart';
import 'package:tripapp/trip_home/receipts/receipt_draft.dart';

void main() {
  test(
    'applied fees and discount lines persist without changing the final payment',
    () {
      final draft = ReceiptDraft.fromLlm({
        'merchant': 'SAMPLE CAFE',
        'date': '2026-10-04',
        'currency': 'KRW',
        'amount': 10500,
        'items': [],
        'warnings': [],
        'adjustments': {
          'discount': 1000,
          'currency': 'KRW',
          'details': [
            {
              'label': '서비스료',
              'kind': 'surcharge',
              'amount': 1000,
              'currency': 'KRW',
            },
            {
              'label': '포장비',
              'kind': 'surcharge',
              'amount': 500,
              'currency': 'KRW',
            },
            {
              'label': '쿠폰 할인',
              'kind': 'discount',
              'amount': 1000,
              'currency': 'KRW',
            },
          ],
        },
      });
      final restored = ReceiptAdjustments.fromJson(
        draft.adjustments!.toJson(),
      )!;
      expect(restored.details.map((line) => line.amount), [1000, 500, 1000]);
      expect(restored.details.last.isDiscount, isTrue);
      expect(draft.amount, 10500);
      for (final bad in [double.nan, -1, double.infinity, 1e13]) {
        expect(
          ReceiptAdjustmentLine.fromJson({
            'label': '팁',
            'kind': 'surcharge',
            'currency': 'KRW',
            'amount': bad,
          }),
          isNull,
        );
      }
      expect(
        ReceiptAdjustments.fromJson({
          'details': [
            {'label': '팁', 'kind': 'offer', 'currency': 'KRW', 'amount': 500},
          ],
        }),
        isNull,
      );
    },
  );
  test(
    'explicit exemption and discount are metadata, not another deduction',
    () {
      final data = {
        'merchant': 'SAMPLE TAX FREE',
        'date': '2026-10-04',
        'currency': 'KRW',
        'amount': 9500,
        'items': [],
        'warnings': [],
        'adjustments': {
          'taxFree': true,
          'exemptedTax': 1000,
          'taxFreeBase': null,
          'discount': 500,
          'currency': 'KRW',
        },
      };
      final draft = ReceiptDraft.fromLlm(data);
      expect(draft.adjustments!.taxFree, isTrue);
      expect(draft.adjustments!.exemptedTax, 1000);
      expect(draft.adjustments!.taxFreeBase, isNull);
      expect(draft.adjustments!.discount, 500);
      expect(draft.amount, 9500);
      expect(
        ReceiptDraft.fromLlm({
          ...data,
          'adjustments': {'taxFree': null},
        }).adjustments,
        isNull,
      );
      expect(
        ReceiptDraft.fromLlm({
          ...data,
          'adjustments': {'discount': -500},
        }).adjustments,
        isNull,
      );
    },
  );
  test(
    'only explicit valid taxes survive; total is not inflated and missing tax is not zero',
    () {
      final data = {
        'merchant': 'TEST CAFE',
        'date': '2026-10-04',
        'currency': 'KRW',
        'amount': 5000,
        'items': [],
        'warnings': [],
      };
      final draft = ReceiptDraft.fromLlm({
        ...data,
        'taxes': [
          {'label': '부가세', 'amount': 455, 'currency': 'KRW', 'included': true},
          {'label': '소비세', 'amount': 0, 'currency': 'JPY', 'included': null},
          {'label': '세금', 'amount': null, 'currency': 'KRW', 'included': null},
        ],
      });
      expect(draft.amount, 5000);
      expect(draft.taxes.map((tax) => tax.amount), [455, 0]);
      expect(ReceiptTax.fromJson(draft.taxes.first.toJson())!.label, '부가세');
      expect(draft.warnings.any((warning) => warning.contains('세금')), isTrue);
      expect(ReceiptDraft.fromLlm(data).taxes, isEmpty);
      expect(
        ReceiptTax.fromJson({
          'label': '세금',
          'amount': double.nan,
          'currency': 'KRW',
        }),
        isNull,
      );
    },
  );
  test('category uses item content and validated model recommendation', () {
    for (final pair in {
      'Americano': '식비',
      '스테이크 우유 밥': '식비',
      'Train ticket': '교통',
      'Hotel room night': '숙박',
      'Museum admission': '관광',
      'Souvenir': '쇼핑',
      'Unknown': '기타',
    }.entries) {
      final data = <String, dynamic>{
        'merchant': 'SAMPLE STORE',
        'date': '2026-10-06',
        'currency': 'KRW',
        'amount': 5000,
        'warnings': [],
        'items': [
          {'name': pair.key, 'quantity': 1, 'unit_price': 5000, 'amount': 5000},
        ],
      };
      expect(ReceiptDraft.fromLlm(data).category, pair.value);
      expect(ReceiptDraft.fromLlm({...data, 'category': '관광'}).category, '관광');
      expect(
        ReceiptDraft.fromLlm({...data, 'category': '없는 카테고리'}).category,
        pair.value,
      );
      expect(
        ReceiptDraft.parse(
          'SAMPLE STORE\n${pair.key} 1 5000\nTOTAL 5000 KRW',
        ).category,
        pair.value,
      );
    }
  });
  test(
    'LLM draft preserves final total and item prices; conflicting dates stay empty',
    () {
      final draft = ReceiptDraft.fromLlm({
        'merchant': 'SAMPLE CAFE',
        'date': null,
        'amount': 7600,
        'currency': 'KRW',
        'warnings': ['거래일과 승인일이 달라요.'],
        'items': [
          {'name': 'Tea', 'quantity': 2, 'unit_price': 3800, 'amount': 7600},
        ],
      });
      expect(draft.amount, 7600);
      expect(draft.date, isNull);
      expect(draft.items.single.unitPrice, 3800);
      expect(
        ReceiptItem.fromJson(draft.items.single.toJson())!.unitPrice,
        3800,
      );
      expect(draft.warnings, contains('거래일과 승인일이 달라요.'));
      final invalid = ReceiptDraft.fromLlm({
        'merchant': null,
        'date': '2026-02-30',
        'amount': -1,
        'currency': 'UNKNOWN',
        'warnings': [],
        'items': [
          {'name': 'Tea', 'quantity': 2, 'unit_price': 3800, 'amount': 3800},
        ],
      });
      expect(invalid.date, isNull);
      expect(invalid.amount, isNull);
      expect(invalid.currency, isNull);
      expect(invalid.items, isEmpty);
      expect(invalid.warnings.length, greaterThanOrEqualTo(5));
    },
  );
}
