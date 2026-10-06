import '../models/country.dart';
import '../models/receipt_item.dart';
import '../models/trip.dart';

/// Suggestions only: review is mandatory. Never add subtotal/tax to total.
class ReceiptDraft {
  ReceiptDraft({
    required this.merchant,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    required this.warnings,
    this.items = const [],
    this.taxes = const [],
    this.adjustments,
  });
  final String merchant;
  final DateTime? date;
  final double? amount;
  final String? currency;
  final String category;
  final List<String> warnings;
  final List<ReceiptItem> items;
  final List<ReceiptTax> taxes;
  final ReceiptAdjustments? adjustments;

  factory ReceiptDraft.fromLlm(Map<String, dynamic> data) {
    final warnings = <String>[
      for (final value
          in (data['warnings'] is List ? data['warnings'] as List : const []))
        if (value is String) value,
    ];
    final merchant = data['merchant'] is String
        ? (data['merchant'] as String).trim()
        : '';
    final currency =
        data['currency'] is String &&
            countryByCode(data['currency'] as String) != null
        ? data['currency'] as String
        : null;
    final rawAmount = data['amount'];
    final amount = rawAmount is num && rawAmount.isFinite && rawAmount >= 0
        ? rawAmount.toDouble()
        : null;
    final rawDate = data['date'];
    final parsedDate =
        rawDate is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)
        ? DateTime.tryParse(rawDate)
        : null;
    final date =
        parsedDate != null &&
            parsedDate.toIso8601String().substring(0, 10) == rawDate
        ? parsedDate
        : null;
    if (merchant.isEmpty) warnings.add('상호명 확인 필요');
    if (currency == null) warnings.add('통화 확인 필요');
    if (amount == null) warnings.add('최종 결제금액 확인 필요');
    if (date == null) warnings.add('날짜 확인 필요: 원본의 결제일을 직접 확인해주세요.');
    if (amount != null && amount != amount.truncate()) {
      warnings.add('소수점 금액은 앱의 정수 계산 규칙에 따라 버려요. 원본 금액을 확인해주세요.');
    }
    final items = <ReceiptItem>[];
    final rows = data['items'] is List ? data['items'] as List : const [];
    if (rows.length > 100) {
      throw const FormatException('Too many receipt items');
    }
    for (final row in rows) {
      final item = row is Map
          ? ReceiptItem.fromJson({
              'name': row['name'],
              'quantity': row['quantity'],
              'amount': row['amount'],
              'unitPrice': row['unit_price'],
            })
          : null;
      if (item == null ||
          (item.unitPrice != null &&
              (item.unitPrice! * item.quantity - item.amount).abs() > .01)) {
        warnings.add('불명확하거나 단가·수량·금액이 맞지 않는 품목은 제외했어요. 원본을 확인해주세요.');
      } else {
        items.add(item);
      }
    }
    if (amount != null &&
        items.isNotEmpty &&
        (items.fold<double>(0, (sum, item) => sum + item.amount) - amount)
                .abs() >
            .01) {
      warnings.add('품목 합계와 결제금액이 달라요. 할인·세금·누락 품목을 원본에서 확인해주세요.');
    }
    final taxes = <ReceiptTax>[];
    final adjustments = ReceiptAdjustments.fromJson(data['adjustments']);
    if (data['adjustments'] != null && adjustments == null) {
      warnings.add('면세·추가금·할인 정보 확인 필요');
    }
    if (adjustments != null &&
        (adjustments.exemptedTax != null ||
            adjustments.taxFreeBase != null ||
            adjustments.discount != null) &&
        countryByCode(adjustments.currency ?? '') == null) {
      warnings.add('면세·할인 금액의 통화 확인 필요');
    }
    if (adjustments?.details.any(
          (line) => countryByCode(line.currency) == null,
        ) ==
        true) {
      warnings.add('추가금·할인 금액의 통화 확인 필요');
    }
    final taxRows = data['taxes'] is List ? data['taxes'] as List : const [];
    if (taxRows.length > 10) {
      throw const FormatException('Too many receipt taxes');
    }
    for (final row in taxRows) {
      final tax = ReceiptTax.fromJson(row);
      if (tax == null || countryByCode(tax.currency) == null) {
        warnings.add('세금 금액·통화 확인 필요: 원본을 확인해주세요.');
      } else {
        taxes.add(tax);
      }
    }
    final category = expenseCategoryIcons.containsKey(data['category'])
        ? data['category'] as String
        : _suggestCategory(
            '$merchant\n${items.map((item) => item.name).join('\n')}',
          );
    return ReceiptDraft(
      merchant: merchant,
      date: date,
      amount: amount,
      currency: currency,
      category: category,
      warnings: warnings.toSet().toList(),
      items: items,
      taxes: taxes,
      adjustments: adjustments?.hasInformation == true ? adjustments : null,
    );
  }

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
    final merchantLines = lines
        .where(
          (line) =>
              !RegExp(
                r'(receipt|영수증|領収|total|합계|결제|\d{4}[-/.]|tax|세금|이용\s*가이드|주문\s*번호|상품명|수량|단가|금액|TEL)',
                caseSensitive: false,
              ).hasMatch(line) &&
              RegExp(r'[a-zA-Z가-힣ぁ-んァ-ン一-龯]').hasMatch(line),
        )
        .toList();
    final merchant =
        merchantLines
            .where(
              (line) => RegExp(
                r'(카페|식당|호텔|cafe|coffee|restaurant|hotel|カフェ)',
                caseSensitive: false,
              ).hasMatch(line),
            )
            .firstOrNull ??
        merchantLines.firstOrNull ??
        '';
    if (merchant.isEmpty) warnings.add('상호명 확인 필요');
    if (confidence < 65) warnings.add('인식 신뢰도가 낮아요. 모든 항목을 원본과 비교해주세요.');
    final items = _parseItems(lines);
    final category = _suggestCategory(
      '$merchant\n${items.map((item) => item.name).join('\n')}',
    );
    return ReceiptDraft(
      merchant: merchant,
      date: date,
      amount: amount,
      currency: currency,
      category: category,
      warnings: warnings,
      items: items,
    );
  }

  // Legacy/device OCR fallback. Gemini uses the full receipt to recommend instead.
  static String _suggestCategory(String text) {
    const keywords = {
      '숙박': r'(hotel|hostel|lodging|room night|호텔|숙박|旅館)',
      '교통':
          r'(taxi|rail|metro|train|bus ticket|parking|fuel|택시|철도|기차|버스|주차|주유|駅)',
      '관광': r'(museum|admission|theme park|tour ticket|박물관|입장권|전망대|놀이공원)',
      '식비':
          r'(cafe|coffee|restaurant|americano|latte|steak|milk|rice|tea|식당|카페|라멘|커피|스테이크|우유|밥|식사|ラーメン|カフェ)',
      '쇼핑': r'(clothing|souvenir|cosmetic|t-shirt|셔츠|의류|기념품|화장품)',
    };
    for (final entry in keywords.entries) {
      if (RegExp(entry.value, caseSensitive: false).hasMatch(text)) {
        return entry.key;
      }
    }
    return '기타';
  }

  static List<ReceiptItem> _parseItems(List<String> lines) {
    final items = <ReceiptItem>[];
    // Only explicit quantity/line-total rows qualify; headers and tax totals do not.
    final row = RegExp(
      r'^(.+?)\s+(?:(\d[\d,]*(?:\.\d{1,2})?)\s+)?(\d{1,3})\s+(\d[\d,]*(?:\.\d{1,2})?)\s*(?:원|KRW|JPY|USD|円)?$',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (RegExp(
        r'(합계|소계|총액|세금|부가|공급|결제|승인|카드|total|tax|change)',
        caseSensitive: false,
      ).hasMatch(line)) {
        continue;
      }
      final match = row.firstMatch(line);
      if (match == null ||
          !RegExp(r'[A-Za-z가-힣ぁ-んァ-ン一-龯]').hasMatch(match[1]!)) {
        continue;
      }
      final quantity = int.parse(match[3]!);
      final amount = double.tryParse(match[4]!.replaceAll(',', ''));
      final unit = double.tryParse((match[2] ?? '').replaceAll(',', ''));
      if (quantity < 1 ||
          amount == null ||
          !amount.isFinite ||
          amount < 0 ||
          (unit != null && (unit * quantity - amount).abs() > .01)) {
        continue;
      }
      final item = ReceiptItem.fromJson({
        'name': match[1]!.trim(),
        'quantity': quantity,
        'amount': amount,
      });
      if (item != null) items.add(item);
    }
    return items;
  }

  String get fingerprint =>
      '$merchant|${date?.toIso8601String().substring(0, 10)}|$currency|${amount?.truncate()}';
}
