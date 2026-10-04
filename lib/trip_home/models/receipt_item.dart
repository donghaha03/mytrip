class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.amount,
  });
  final String name;
  final int quantity;

  /// Line total, not unit price. Never added on top of the receipt total.
  final double amount;

  Map<String, Object> toJson() => {
    'name': name,
    'quantity': quantity,
    'amount': amount,
  };

  static ReceiptItem? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name'],
        quantity = value['quantity'],
        amount = value['amount'];
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
        amount < 0) {
      return null;
    }
    return ReceiptItem(
      name: name.trim(),
      quantity: quantity.toInt(),
      amount: amount.toDouble(),
    );
  }
}
