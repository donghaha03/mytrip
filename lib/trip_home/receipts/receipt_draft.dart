import '../models/country.dart';

/// Suggestions only: review is mandatory. Never add subtotal/tax to total.
class ReceiptDraft {
  ReceiptDraft({
    required this.merchant,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    required this.warnings,
  });
  final String merchant;
  final DateTime? date;
  final double? amount;
  final String? currency;
  final String category;
  final List<String> warnings;

  factory ReceiptDraft.parse(String text, {double confidence = 100}) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final warnings = <String>[];
    final codes = RegExp(r'\b[A-Z]{3}\b')
        .allMatches(text.toUpperCase())
        .map((m) => m[0]!)
        .where((code) => countryByCode(code) != null && code != 'XXX')
        .toSet();
    if (text.contains('円') && codes.isEmpty) codes.add('JPY');
    if (text.contains('원') && codes.isEmpty) codes.add('KRW');
    if (text.contains('€') && codes.isEmpty) codes.add('EUR');
    if (text.contains('₩') && codes.isEmpty) codes.add('KRW');
    final currency = codes.length == 1 ? codes.single : null;
    if (currency == null) warnings.add('통화 확인 필요: 기호만으로는 통화를 확정할 수 없어요.');

    final totals = <double>[];
    final totalLabel = RegExp(
      r'(grand\s*total|amount\s*(due|paid)|total|합계|총\s*액|결제\s*금액|합\s*계|合計|お支払)',
      caseSensitive: false,
    );
    final excluded = RegExp(
      r'(sub\s*total|소계|小計|tax|세금|부가세|消費税|change|거스름|お釣)',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (!totalLabel.hasMatch(line) || excluded.hasMatch(line)) continue;
      // A single final-amount line is safe to propose. Locale-ambiguous numbers
      // or differing total lines require review rather than guessing the max.
      final tail = line.substring(totalLabel.firstMatch(line)!.end);
      final matches = RegExp(
        r'-?\d[\d,.]*(?:\s|$|[^\d,.])',
      ).allMatches(tail).toList();
      if (matches.length != 1) continue;
      final token = RegExp(r'-?\d[\d,.]*').firstMatch(matches.single[0]!)![0]!;
      final valid = RegExp(
        r'^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$',
      ).hasMatch(token);
      if (!valid) continue;
      final value = double.tryParse(token.replaceAll(',', ''));
      if (value != null && value.isFinite && value >= 0) totals.add(value);
    }
    final distinct = totals.toSet();
    final amount = distinct.length == 1 ? distinct.single : null;
    if (amount == null) warnings.add('최종 결제금액 확인 필요: 소계·세금은 합산하지 않았어요.');
    if (amount != null && amount != amount.truncate()) {
      warnings.add('소수점 금액은 앱의 정수 계산 규칙에 따라 버려요. 원본 금액을 확인해주세요.');
    }

    final dates = <DateTime>{};
    for (final match in RegExp(
      r'(20\d{2}|19\d{2})\s*[-/.년年]\s*(\d{1,2})\s*[-/.월月]\s*(\d{1,2})(?:일|日)?',
    ).allMatches(text)) {
      final y = int.parse(match[1]!),
          m = int.parse(match[2]!),
          d = int.parse(match[3]!);
      final candidate = DateTime(y, m, d);
      if (candidate.year == y && candidate.month == m && candidate.day == d) {
        dates.add(candidate);
      }
    }
    final date = dates.length == 1 ? dates.single : null;
    if (date == null) warnings.add('날짜 확인 필요: 원본의 결제일을 직접 확인해주세요.');
    final merchant =
        lines
            .where(
              (line) =>
                  !RegExp(
                    r'(receipt|영수증|領収|total|합계|결제|\d{4}[-/.]|tax|세금)',
                    caseSensitive: false,
                  ).hasMatch(line) &&
                  RegExp(r'[a-zA-Z가-힣ぁ-んァ-ン一-龯]').hasMatch(line),
            )
            .firstOrNull ??
        '';
    if (merchant.isEmpty) warnings.add('상호명 확인 필요');
    if (confidence < 65) warnings.add('인식 신뢰도가 낮아요. 모든 항목을 원본과 비교해주세요.');
    final category =
        RegExp(
          r'(cafe|coffee|restaurant|식당|카페|라멘|ラーメン|カフェ)',
          caseSensitive: false,
        ).hasMatch(merchant)
        ? '식비'
        : RegExp(r'(hotel|호텔|宿|旅館)', caseSensitive: false).hasMatch(merchant)
        ? '숙박'
        : RegExp(
            r'(taxi|rail|metro|택시|철도|駅)',
            caseSensitive: false,
          ).hasMatch(merchant)
        ? '교통'
        : '기타';
    return ReceiptDraft(
      merchant: merchant,
      date: date,
      amount: amount,
      currency: currency,
      category: category,
      warnings: warnings,
    );
  }

  String get fingerprint =>
      '$merchant|${date?.toIso8601String().substring(0, 10)}|$currency|${amount?.truncate()}';
}
