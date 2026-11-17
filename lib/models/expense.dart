import 'package:cloud_firestore/cloud_firestore.dart';

import 'receipt_item.dart';

enum PaymentMethod {
  cash('현금'),
  card('카드');

  const PaymentMethod(this.label);
  final String label;
}

enum ExpenseStatus {
  approved('승인'),
  partiallyCancelled('부분 취소'),
  cancelled('취소'),
  declined('거절');

  const ExpenseStatus(this.label);
  final String label;
  bool get countsAsSpending => this == approved || this == partiallyCancelled;
}

/// users/{uid}/trips/{tripId}/expenses/{id}
class Expense {
  final String id;
  final String category;
  final String place; // 사용처
  final double amount; // 현지 화폐 금액
  final String currency;
  final double rate; // 기록 시점 환율 (1 현지통화 = rate 원)
  final DateTime date;

  final String icon;
  final PaymentMethod? paymentMethod;
  final bool isTaxFree;
  final String memo;
  final int? recordedQuote;
  final String? source;
  final ExpenseStatus status;
  final double? originalAmount;
  final String? receiptFingerprint;
  final List<ReceiptItem> receiptItems;
  final List<ReceiptTax> receiptTaxes;
  final ReceiptAdjustments? receiptAdjustments;

  bool get isImported => source != null;

  const Expense({
    required this.id,
    required this.category,
    required this.place,
    required this.amount,
    required this.currency,
    required this.rate,
    required this.date,
    this.icon = '💸',
    this.paymentMethod,
    this.isTaxFree = false,
    this.memo = '',
    this.recordedQuote,
    this.source,
    this.status = ExpenseStatus.approved,
    this.originalAmount,
    this.receiptFingerprint,
    this.receiptItems = const [],
    this.receiptTaxes = const [],
    this.receiptAdjustments,
  });

  /// 원화 환산 금액
  double get amountKrw => status.countsAsSpending ? amount * rate : 0;

  Expense copyWith({
    String? category,
    String? place,
    double? amount,
    double? rate,
    DateTime? date,
    String? icon,
    PaymentMethod? paymentMethod,
    bool? isTaxFree,
    String? memo,
    int? recordedQuote,
    String? source,
    ExpenseStatus? status,
    double? originalAmount,
    String? receiptFingerprint,
    List<ReceiptItem>? receiptItems,
    List<ReceiptTax>? receiptTaxes,
    ReceiptAdjustments? receiptAdjustments,
  }) => Expense(
    id: id,
    category: category ?? this.category,
    place: place ?? this.place,
    amount: amount ?? this.amount,
    currency: currency,
    rate: rate ?? this.rate,
    date: date ?? this.date,
    icon: icon ?? this.icon,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    isTaxFree: isTaxFree ?? this.isTaxFree,
    memo: memo ?? this.memo,
    recordedQuote: recordedQuote ?? this.recordedQuote,
    source: source ?? this.source,
    status: status ?? this.status,
    originalAmount: originalAmount ?? this.originalAmount,
    receiptFingerprint: receiptFingerprint ?? this.receiptFingerprint,
    receiptItems: receiptItems ?? this.receiptItems,
    receiptTaxes: receiptTaxes ?? this.receiptTaxes,
    receiptAdjustments: receiptAdjustments ?? this.receiptAdjustments,
  );

  Map<String, dynamic> toMap() => {
    'category': category,
    'place': place,
    'amount': amount,
    'currency': currency,
    'rate': rate,
    'date': Timestamp.fromDate(date),
    'icon': icon,
    'paymentMethod': paymentMethod?.name,
    'isTaxFree': isTaxFree,
    'memo': memo,
    'recordedQuote': recordedQuote,
    'source': source,
    'status': status.name,
    'originalAmount': originalAmount,
    'receiptFingerprint': receiptFingerprint,
    'receiptItems': receiptItems.map((item) => item.toJson()).toList(),
    'receiptTaxes': receiptTaxes.map((tax) => tax.toJson()).toList(),
    'receiptAdjustments': receiptAdjustments?.toJson(),
  };

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Expense.fromMap(doc.id, d);
  }

  factory Expense.fromMap(String id, Map<String, dynamic> d) {
    return Expense(
      id: id,
      category: d['category'] ?? '기타',
      place: d['place'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      currency: d['currency'] ?? 'USD',
      rate: (d['rate'] ?? 0).toDouble(),
      date: (d['date'] as Timestamp).toDate(),
      icon: d['icon'] as String? ?? '💸',
      paymentMethod: PaymentMethod.values
          .where((m) => m.name == d['paymentMethod'])
          .firstOrNull,
      isTaxFree: d['isTaxFree'] == true,
      memo: d['memo'] as String? ?? '',
      recordedQuote: (d['recordedQuote'] as num?)?.toInt(),
      source: d['source'] as String?,
      status:
          ExpenseStatus.values
              .where((s) => s.name == d['status'])
              .firstOrNull ??
          ExpenseStatus.approved,
      originalAmount: (d['originalAmount'] as num?)?.toDouble(),
      receiptFingerprint: d['receiptFingerprint'] as String?,
      receiptItems:
          (d['receiptItems'] is List ? d['receiptItems'] as List : const [])
              .map(ReceiptItem.fromJson)
              .nonNulls
              .toList(),
      receiptTaxes:
          (d['receiptTaxes'] is List ? d['receiptTaxes'] as List : const [])
              .map(ReceiptTax.fromJson)
              .nonNulls
              .toList(),
      receiptAdjustments: ReceiptAdjustments.fromJson(d['receiptAdjustments']),
    );
  }
}
