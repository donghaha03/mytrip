/// 영수증 인식 서버가 돌려주는 초안을 읽는다 (순수 Dart).
///
/// 서버 계약과 같은 규칙으로 다시 검사해서, 형식이 틀린 응답은 화면에 내보내지 않는다.
library;

const ocrCategories = ['식비', '교통', '숙박', '쇼핑', '관광', '기타'];
const _taxLabels = ['부가세', '소비세', '세금'];

class OcrItem {
  const OcrItem({this.name, this.quantity, this.unitPrice, this.amount});
  final String? name;
  final int? quantity;
  final double? unitPrice;
  final double? amount;
}

class OcrTax {
  const OcrTax({
    required this.label,
    this.amount,
    this.currency,
    this.included,
  });
  final String label; // 부가세 / 소비세 / 세금
  final double? amount;
  final String? currency;

  /// 최종 결제액에 포함됐는지. 영수증에서 알 수 없으면 null.
  final bool? included;
}

/// 적용된 추가금(서비스료·팁 등) 또는 할인(쿠폰 등) 한 줄.
class OcrAdjustment {
  const OcrAdjustment({
    required this.label,
    required this.isDiscount,
    required this.amount,
    required this.currency,
  });
  final String label;
  final bool isDiscount;
  final double amount;
  final String currency;
}

class OcrReceipt {
  const OcrReceipt({
    this.merchant,
    this.date,
    this.currency,
    this.amount,
    this.category = '기타',
    this.items = const [],
    this.taxes = const [],
    this.taxFree,
    this.exemptedTax,
    this.taxFreeBase,
    this.discount,
    this.adjustmentCurrency,
    this.adjustments = const [],
    this.warnings = const [],
  });

  final String? merchant;
  final DateTime? date;
  final String? currency;

  /// 최종 결제액. 세금·할인·면세는 이미 반영된 값이라 다시 더하거나 빼지 않는다.
  final double? amount;
  final String category;
  final List<OcrItem> items;
  final List<OcrTax> taxes;

  /// 면세가 적용됐다고 영수증에 적혀 있으면 true, 적용 안 됨이 명시되면 false.
  final bool? taxFree;
  final double? exemptedTax; // 면세로 빠진 세금
  final double? taxFreeBase; // 면세 대상 구매금액
  final double? discount; // 적용된 할인 합계
  final String? adjustmentCurrency;
  final List<OcrAdjustment> adjustments;
  final List<String> warnings;

  /// 서버 응답의 `draft`를 읽는다. 계약과 다르면 [FormatException].
  factory OcrReceipt.fromDraft(Object? draft) {
    if (draft is! Map) throw const FormatException('draft');
    final adjustments = draft['adjustments'];
    if (adjustments != null && adjustments is! Map) {
      throw const FormatException('adjustments');
    }
    final category = draft['category'] ?? '기타';
    if (!ocrCategories.contains(category)) {
      throw const FormatException('category');
    }
    return OcrReceipt(
      merchant: _text(draft['merchant']),
      date: _date(draft['date']),
      currency: _currency(draft['currency']),
      amount: _money(draft['amount']),
      category: category as String,
      items: _list(draft['items'], 100, (Map item) {
        final quantity = item['quantity'];
        if (quantity != null &&
            (quantity is! int || quantity < 0 || quantity > 10000)) {
          throw const FormatException('quantity');
        }
        return OcrItem(
          name: _text(item['name']),
          quantity: quantity as int?,
          unitPrice: _money(item['unit_price']),
          amount: _money(item['amount']),
        );
      }),
      taxes: _list(draft['taxes'] ?? const [], 10, (Map tax) {
        final label = tax['label'], included = tax['included'];
        if (!_taxLabels.contains(label) ||
            (included != null && included is! bool)) {
          throw const FormatException('tax');
        }
        return OcrTax(
          label: label as String,
          amount: _money(tax['amount']),
          currency: _currency(tax['currency']),
          included: included as bool?,
        );
      }),
      taxFree: _bool(adjustments?['taxFree']),
      exemptedTax: _money(adjustments?['exemptedTax'], negative: false),
      taxFreeBase: _money(adjustments?['taxFreeBase'], negative: false),
      discount: _money(adjustments?['discount'], negative: false),
      adjustmentCurrency: _currency(adjustments?['currency']),
      adjustments: _list(adjustments?['details'] ?? const [], 20, (Map line) {
        final label = line['label'], kind = line['kind'];
        final amount = _money(line['amount'], negative: false);
        final currency = _currency(line['currency']);
        if (label is! String ||
            label.trim().isEmpty ||
            label.length > 50 ||
            (kind != 'surcharge' && kind != 'discount') ||
            amount == null ||
            currency == null) {
          throw const FormatException('adjustment');
        }
        return OcrAdjustment(
          label: label.trim(),
          isDiscount: kind == 'discount',
          amount: amount,
          currency: currency,
        );
      }),
      warnings: _list<Object?, String>(draft['warnings'], 20, (warning) {
        if (warning is! String || warning.length > 300) {
          throw const FormatException('warning');
        }
        return warning;
      }),
    );
  }
}

List<T> _list<E, T>(Object? value, int max, T Function(E) read) {
  if (value is! List || value.length > max) throw const FormatException('list');
  return [
    for (final entry in value)
      if (entry is E) read(entry) else throw const FormatException('entry'),
  ];
}

String? _text(Object? value) {
  if (value == null) return null;
  if (value is! String || value.length > 300) {
    throw const FormatException('text');
  }
  return value.trim().isEmpty ? null : value.trim();
}

double? _money(Object? value, {bool negative = true}) {
  if (value == null) return null;
  if (value is! num ||
      !value.isFinite ||
      value.abs() > 1e12 ||
      (!negative && value < 0)) {
    throw const FormatException('money');
  }
  return value.toDouble();
}

String? _currency(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(value)) {
    throw const FormatException('currency');
  }
  return value;
}

bool? _bool(Object? value) {
  if (value == null) return null;
  if (value is! bool) throw const FormatException('bool');
  return value;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  final match = value is String
      ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value)
      : null;
  if (match == null) throw const FormatException('date');
  final year = int.parse(match[1]!), month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  // 2026-02-30처럼 없는 날짜는 거부한다.
  if (date.year != year || date.month != month || date.day != day) {
    throw const FormatException('date');
  }
  return date;
}
