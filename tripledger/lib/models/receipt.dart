// [OCR] 영수증 OCR 기능 (feature/receipt-ocr)
import '../constants.dart';

/// 영수증 인식 결과. 지출 추가 시트를 미리 채우는 데만 쓰고 Firestore에는 저장하지 않는다.
/// 읽지 못한 값은 null(장소는 빈 문자열)이며, 사용자가 시트에서 확인·수정한 뒤 저장한다.
class Receipt {
  final String place; // 가맹점 (최대 50자)
  final double? amount; // 최종 결제액. 지원하지 않는 통화면 null
  final String? currency; // 앱이 환율을 아는 통화만. null이면 여행 통화를 쓴다

  /// 영수증에서 읽었지만 앱이 환율을 모르는 통화(예: CAD). 이때 [amount]는 비운다.
  /// 그 금액을 여행 통화 금액으로 저장하면 안 되기 때문이다.
  final String? unsupportedCurrency;
  final DateTime? date; // 영수증 날짜 + 지금 시각. null이면 지금
  final String category; // categoryIcons의 키 중 하나
  final String paymentMethod; // cash 또는 card

  const Receipt({
    this.place = '',
    this.amount,
    this.currency,
    this.unsupportedCurrency,
    this.date,
    this.category = '기타',
    this.paymentMethod = 'cash',
  });

  /// 인식 서버 응답의 `draft`를 읽는다. 형식이 다른 값은 버리고 기본값을 쓴다.
  factory Receipt.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    now ??= DateTime.now();

    final merchant = json['merchant'];
    final place = merchant is String ? merchant.trim() : '';

    final amount = json['amount'];
    final currency = json['currency'];
    final category = json['category'];

    // 목록 밖 통화는 RateApi가 환율을 몰라 저장할 수 없다.
    // 통화를 아예 못 읽은 경우(null·빈 값)는 여행 통화로 보고 금액을 그대로 둔다.
    final supported = currency == 'KRW' || currencies.contains(currency);
    final unsupported =
        !supported && currency is String && currency.trim().isNotEmpty
        ? currency.trim()
        : null;

    // 영수증에는 날짜만 있으므로 시각은 지금으로 채운다(같은 날 지출의 정렬 순서 유지).
    // 없는 날짜(02-30)나 미래 날짜는 잘못 읽은 것으로 보고 버린다.
    DateTime? date;
    final day = json['date'];
    final match = day is String
        ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day)
        : null;
    if (match != null) {
      final y = int.parse(match[1]!), m = int.parse(match[2]!);
      final d = int.parse(match[3]!);
      final parsed = DateTime(y, m, d, now.hour, now.minute);
      if (parsed.month == m && parsed.day == d && !parsed.isAfter(now)) {
        date = parsed;
      }
    }

    // 서버가 결제수단을 따로 주지 않으므로, 카드 결제로 볼 근거(카드 수수료 등 조정 항목)가
    // 있을 때만 card로 본다.
    final adjustments = json['adjustments'];
    final details = adjustments is Map ? adjustments['details'] : null;
    final card =
        json['paymentMethod'] == 'card' ||
        (details is List &&
            details.any(
              (line) =>
                  line is Map && '${line['label']}'.contains(RegExp('카드|card')),
            ));

    return Receipt(
      place: place.length > 50 ? place.substring(0, 50) : place,
      amount:
          unsupported == null && amount is num && amount.isFinite && amount > 0
          ? amount.toDouble()
          : null,
      currency: supported ? currency as String : null,
      unsupportedCurrency: unsupported,
      date: date,
      category: categoryIcons.containsKey(category) ? category as String : '기타',
      paymentMethod: card ? 'card' : 'cash',
    );
  }
}
