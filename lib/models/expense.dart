import 'package:cloud_firestore/cloud_firestore.dart';

/// users/{uid}/trips/{tripId}/expenses/{id}
class Expense {
  final String id;
  final String category;
  final String place; // 사용처
  final double amount; // 현지 화폐 금액
  final String currency;
  final double rate; // 기록 시점 환율 (1 현지통화 = rate 원)
  final DateTime date;

  const Expense({
    required this.id,
    required this.category,
    required this.place,
    required this.amount,
    required this.currency,
    required this.rate,
    required this.date,
  });

  /// 원화 환산 금액
  double get amountKrw => amount * rate;

  Expense copyWith({
    String? category,
    String? place,
    double? amount,
    double? rate,
    DateTime? date,
  }) => Expense(
    id: id,
    category: category ?? this.category,
    place: place ?? this.place,
    amount: amount ?? this.amount,
    currency: currency,
    rate: rate ?? this.rate,
    date: date ?? this.date,
  );

  Map<String, dynamic> toMap() => {
    'category': category,
    'place': place,
    'amount': amount,
    'currency': currency,
    'rate': rate,
    'date': Timestamp.fromDate(date),
  };

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Expense(
      id: doc.id,
      category: d['category'] ?? '기타',
      place: d['place'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      currency: d['currency'] ?? 'USD',
      rate: (d['rate'] ?? 0).toDouble(),
      date: (d['date'] as Timestamp).toDate(),
    );
  }
}
