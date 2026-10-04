import 'package:flutter/material.dart';

import '../../api/api.dart';
import 'trip.dart';

const categoryColors = <String, Color>{
  '식비': Color(0xFFB7791F),
  '교통': Color(0xFF356E9F),
  '숙박': Color(0xFF7557A3),
  '쇼핑': Color(0xFFA85177),
  '관광': Color(0xFF397C69),
  '기타': Color(0xFF64748B),
  '미분류': Color(0xFF858B94),
};
String normalizedCategory(String value) => value == '숙소'
    ? '숙박'
    : categoryColors.containsKey(value)
    ? value
    : '미분류';
Color categoryColor(String value) => categoryColors[normalizedCategory(value)]!;

/// Entire selected trip, all recorded dates. Pie = retained positive payments;
/// negative refunds are separate, never negative wedges. Missing rates block
/// combined KRW totals rather than silently treating unknown money as zero.
class SpendingSummary {
  SpendingSummary(Trip trip) {
    for (final e in trip.expenses) {
      final code = e.currencyOf(trip);
      if (e.status == ExpenseStatus.declined || !e.amount.isFinite) continue;
      final active = e.status.countsAsSpending ? e.amount : 0.0;
      final returned =
          e.originalAmount == null ||
              (e.status != ExpenseStatus.cancelled &&
                  e.status != ExpenseStatus.partiallyCancelled)
          ? 0.0
          : ((e.originalAmount! - active).clamp(0.0, double.infinity));
      if (active != 0) {
        originalCurrencyTotals.update(
          code,
          (n) => n + active,
          ifAbsent: () => active,
        );
        if (RateApi.quotedKrw(code) <= 0) {
          missingCurrencies.add(code);
          continue;
        }
      }
      final krw = RateApi.toKrw(active, code);
      if (RateApi.quotedKrw(code) > 0) {
        cancellationsKrw += RateApi.toKrw(returned, code);
      } else if (returned > 0) {
        unconvertedCancellations.update(
          code,
          (n) => n + returned,
          ifAbsent: () => returned,
        );
      }
      if (krw < 0) {
        refundsKrw -= krw;
        continue;
      }
      if (krw == 0) continue;
      final category = normalizedCategory(e.category);
      categories.update(category, (n) => n + krw, ifAbsent: () => krw);
      positiveKrw += krw;
    }
  }
  final categories = <String, int>{};
  final originalCurrencyTotals = <String, double>{};
  final missingCurrencies = <String>{};
  final unconvertedCancellations = <String, double>{};
  int positiveKrw = 0, refundsKrw = 0, cancellationsKrw = 0;
  int get netKrw => positiveKrw - refundsKrw;
  bool get available => missingCurrencies.isEmpty;
  double share(String category) =>
      positiveKrw == 0 ? 0 : (categories[category] ?? 0) / positiveKrw;
  double budgetRatio(int budget) =>
      !available || budget <= 0 ? 0 : (netKrw / budget).clamp(0.0, 1.0);
  List<MapEntry<String, int>> get sorted =>
      categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
