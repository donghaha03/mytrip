import 'package:cloud_firestore/cloud_firestore.dart';

/// users/{uid}/trips/{tripId}
class Trip {
  final String id;
  final String name;
  final int budget; // 원화(KRW)
  final String currency; // 현지 통화 코드
  final DateTime start;
  final DateTime end;

  const Trip({
    required this.id,
    required this.name,
    required this.budget,
    required this.currency,
    required this.start,
    required this.end,
  });

  Trip copyWith({
    String? name,
    int? budget,
    String? currency,
    DateTime? start,
    DateTime? end,
  }) => Trip(
    id: id,
    name: name ?? this.name,
    budget: budget ?? this.budget,
    currency: currency ?? this.currency,
    start: start ?? this.start,
    end: end ?? this.end,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'budget': budget,
    'currency': currency,
    'start': Timestamp.fromDate(start),
    'end': Timestamp.fromDate(end),
  };

  factory Trip.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Trip(
      id: doc.id,
      name: d['name'] ?? '',
      budget: (d['budget'] ?? 0).toInt(),
      currency: d['currency'] ?? 'USD',
      start: (d['start'] as Timestamp).toDate(),
      end: (d['end'] as Timestamp).toDate(),
    );
  }
}
