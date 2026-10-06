import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/trip_home/models/receipt_item.dart';
import 'package:tripapp/trip_home/receipts/receipt_draft.dart';

void main() {
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
