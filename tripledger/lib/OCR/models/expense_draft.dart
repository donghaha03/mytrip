import '../../constants.dart' show currencies;
import 'ocr_receipt.dart';

/// 영수증 인식 결과로 만든 지출 초안. 사용자가 확인·수정한 뒤 `ExpenseApi.add`로 저장한다.
class ExpenseDraft {
  const ExpenseDraft({
    required this.category,
    required this.place,
    required this.amount,
    required this.currency,
    required this.date,
    this.notes = const [],
  });

  final String category;
  final String place; // 가맹점 (최대 50자)
  final double? amount; // 최종 결제액. 못 읽었으면 null → 사용자가 입력
  final String currency;
  final DateTime date;

  /// 저장 전에 사용자가 확인해야 할 점.
  final List<String> notes;

  /// 앱이 환율을 아는 통화(원화 + constants.dart의 지원 통화).
  static bool supports(String currency) =>
      currency == 'KRW' || currencies.contains(currency);

  /// - 통화: 영수증 통화를 앱이 지원하면 그대로, 아니면 여행 통화.
  /// - 날짜: 영수증 날짜 + 지금 시각. 날짜가 없거나 미래면 지금.
  /// - 금액: 0보다 큰 최종 결제액만. 세금·할인은 이미 반영돼 있어 다시 계산하지 않는다.
  factory ExpenseDraft.fromReceipt(
    OcrReceipt receipt, {
    required String tripCurrency,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final notes = <String>[...receipt.warnings];

    final read = receipt.currency;
    final currency = read != null && supports(read) ? read : tripCurrency;
    if (read == null) {
      notes.add('영수증에서 통화를 읽지 못해 $tripCurrency로 채웠어요.');
    } else if (read != currency) {
      notes.add('$read는 지원하지 않는 통화라 $tripCurrency로 채웠어요. 금액을 확인해주세요.');
    }

    final amount = receipt.amount;
    if (amount == null || amount <= 0) notes.add('결제 금액을 읽지 못했어요. 직접 입력해주세요.');

    final day = receipt.date;
    final date = day == null
        ? now
        : DateTime(day.year, day.month, day.day, now.hour, now.minute);
    if (day == null) notes.add('영수증에서 날짜를 읽지 못해 오늘로 채웠어요.');
    if (date.isAfter(now)) notes.add('영수증 날짜가 미래라 오늘로 채웠어요.');

    final place = receipt.merchant ?? '';
    return ExpenseDraft(
      category: receipt.category,
      place: place.length > 50 ? place.substring(0, 50) : place,
      amount: amount != null && amount > 0 ? amount : null,
      currency: currency,
      date: date.isAfter(now) ? now : date,
      notes: notes,
    );
  }
}
