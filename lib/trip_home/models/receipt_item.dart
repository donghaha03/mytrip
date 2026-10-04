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
