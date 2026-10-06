/// Explicit receipt adjustments only; never deducted from the paid total again.
class ReceiptAdjustments {
  const ReceiptAdjustments({
    this.taxFree,
    this.exemptedTax,
    this.taxFreeBase,
    this.discount,
    this.currency,
    this.details = const [],
  });
  final bool? taxFree;
  final double? exemptedTax, taxFreeBase, discount;
  final String? currency;
  final List<ReceiptAdjustmentLine> details;
  bool get hasInformation =>
      taxFree != null ||
      exemptedTax != null ||
      taxFreeBase != null ||
      discount != null ||
      details.isNotEmpty;
  Map<String, dynamic> toJson() => {
    'taxFree': taxFree,
    'exemptedTax': exemptedTax,
    'taxFreeBase': taxFreeBase,
    'discount': discount,
    'currency': currency,
    if (details.isNotEmpty)
      'details': details.map((line) => line.toJson()).toList(),
  };
  static ReceiptAdjustments? fromJson(Object? value) {
    if (value is! Map ||
        (value['taxFree'] != null && value['taxFree'] is! bool) ||
        (value['currency'] != null &&
            (value['currency'] is! String ||
                !RegExp(
                  r'^[A-Z]{3}$',
                ).hasMatch(value['currency'] as String))) ||
        ['exemptedTax', 'taxFreeBase', 'discount'].any(
          (key) =>
              value[key] != null &&
              (value[key] is! num ||
                  !(value[key] as num).isFinite ||
                  (value[key] as num) < 0 ||
                  (value[key] as num) > 1e12),
        ) ||
        (value['details'] != null &&
            (value['details'] is! List ||
                (value['details'] as List).length > 20 ||
                (value['details'] as List).any(
                  (line) => ReceiptAdjustmentLine.fromJson(line) == null,
                )))) {
      return null;
    }
    return ReceiptAdjustments(
      taxFree: value['taxFree'] as bool?,
      exemptedTax: (value['exemptedTax'] as num?)?.toDouble(),
      taxFreeBase: (value['taxFreeBase'] as num?)?.toDouble(),
      discount: (value['discount'] as num?)?.toDouble(),
      currency: value['currency'] as String?,
      details: [
        for (final line in value['details'] as List? ?? const [])
          ReceiptAdjustmentLine.fromJson(line)!,
      ],
    );
  }
}

/// Applied fees/discounts printed on the receipt; informational, not recalculated.
class ReceiptAdjustmentLine {
  const ReceiptAdjustmentLine({
    required this.label,
    required this.kind,
    required this.amount,
    required this.currency,
  });
  final String label, kind, currency;
  final double amount;
  bool get isDiscount => kind == 'discount';
  Map<String, dynamic> toJson() => {
    'label': label,
    'kind': kind,
    'amount': amount,
    'currency': currency,
  };
  static ReceiptAdjustmentLine? fromJson(Object? value) {
    if (value is! Map ||
        value['label'] is! String ||
        (value['label'] as String).trim().isEmpty ||
        (value['label'] as String).length > 50 ||
        !['surcharge', 'discount'].contains(value['kind']) ||
        value['amount'] is! num ||
        !(value['amount'] as num).isFinite ||
        (value['amount'] as num) < 0 ||
        (value['amount'] as num) > 1e12 ||
        value['currency'] is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(value['currency'] as String)) {
      return null;
    }
    return ReceiptAdjustmentLine(
      label: (value['label'] as String).trim(),
      kind: value['kind'] as String,
      amount: (value['amount'] as num).toDouble(),
      currency: value['currency'] as String,
    );
  }
}

/// Receipt tax metadata only; never added to the recorded payment total.
class ReceiptTax {
  const ReceiptTax({
    required this.label,
    required this.amount,
    required this.currency,
    this.included,
  });
  final String label, currency;
  final double amount;
  final bool? included;
  String get inclusionLabel => included == true
      ? '결제금액에 포함'
      : included == false
      ? '최종 금액에 미포함'
      : '포함 여부 확인 필요';
  Map<String, dynamic> toJson() => {
    'label': label,
    'amount': amount,
    'currency': currency,
    'included': included,
  };
  static ReceiptTax? fromJson(Object? value) {
    if (value is! Map ||
        !['부가세', '소비세', '세금'].contains(value['label']) ||
        value['currency'] is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(value['currency'] as String) ||
        value['amount'] is! num ||
        !(value['amount'] as num).isFinite ||
        (value['amount'] as num).abs() > 1e12 ||
        (value['included'] != null && value['included'] is! bool)) {
      return null;
    }
    return ReceiptTax(
      label: value['label'] as String,
      amount: (value['amount'] as num).toDouble(),
      currency: value['currency'] as String,
      included: value['included'] as bool?,
    );
  }
}

class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.amount,
    this.unitPrice,
  });
  final String name;
  final int quantity;

  /// Line total, not unit price. Never added on top of the receipt total.
  final double amount;
  final double? unitPrice;

  Map<String, Object> toJson() => {
    'name': name,
    'quantity': quantity,
    'amount': amount,
    'unitPrice': ?unitPrice,
  };

  static ReceiptItem? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name'],
        quantity = value['quantity'],
        amount = value['amount'],
        unitPrice = value['unitPrice'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 100 ||
        quantity is! num ||
        !quantity.isFinite ||
        quantity != quantity.toInt() ||
        quantity <= 0 ||
        quantity > 999 ||
        amount is! num ||
        !amount.isFinite ||
        amount < 0 ||
        (unitPrice != null &&
            (unitPrice is! num || !unitPrice.isFinite || unitPrice < 0))) {
      return null;
    }
    return ReceiptItem(
      name: name.trim(),
      quantity: quantity.toInt(),
      amount: amount.toDouble(),
      unitPrice: (unitPrice as num?)?.toDouble(),
    );
  }
}
