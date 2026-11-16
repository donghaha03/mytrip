/// 카드 승인 알림 문자 파서 (순수 Dart, Flutter·Firebase 의존 없음).
///
/// ⚠ 가정: 실제 카드사 문자 샘플 없이 흔히 알려진 형태를 가정해 만들었다.
/// 실제 문자와 다르면 `test/fixtures/card_message_samples.dart`의 샘플을 실제
/// 문자로 바꾸고 아래 정규식을 맞춘다.
library;

/// 알림 한 건에서 읽어낸 결제 정보.
/// 이름·카드번호·누적금액은 일부러 담지 않는다.
class ParsedCardPayment {
  const ParsedCardPayment({
    required this.issuer,
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.date,
    required this.cancelled,
    this.installmentMonths = 0,
  });

  final String issuer; // '신한', 'KB국민' …
  final String merchant;
  final double amount;
  final String currency; // 국내 결제는 KRW
  final DateTime date;
  final bool cancelled; // 승인취소 알림
  final int installmentMonths; // 0 = 일시불

  Map<String, dynamic> toJson() => {
    'issuer': issuer,
    'merchant': merchant,
    'amount': amount,
    'currency': currency,
    'date': date.toIso8601String(),
    'cancelled': cancelled,
    'installmentMonths': installmentMonths,
  };

  static ParsedCardPayment? fromJson(Object? json) {
    if (json is! Map) return null;
    final issuer = json['issuer'], merchant = json['merchant'];
    final amount = json['amount'], currency = json['currency'];
    final date = DateTime.tryParse('${json['date']}');
    if (issuer is! String ||
        merchant is! String ||
        amount is! num ||
        currency is! String ||
        date == null) {
      return null;
    }
    return ParsedCardPayment(
      issuer: issuer,
      merchant: merchant,
      amount: amount.toDouble(),
      currency: currency,
      date: date,
      cancelled: json['cancelled'] == true,
      installmentMonths: (json['installmentMonths'] as num?)?.toInt() ?? 0,
    );
  }
}

// 카드사별 머리말. 뒤따르는 카드번호 끝자리 "(1234)", "1*3*"는 공통 규칙으로 지운다.
final _issuers = <String, RegExp>{
  '신한': RegExp(r'신한(?:카드|체크)'),
  '삼성': RegExp(r'삼성(?:카드|체크)|삼성(?=\s?[\d(*])'),
  'KB국민': RegExp(r'KB\s?국민(?:카드|체크)?|국민카드|KB(?:카드|체크)'),
  // "현대카드 M 승인"처럼 상품명이 붙는 경우
  '현대': RegExp(r'현대카드(?:\s?[A-Z]{1,2}\d?(?=\s*(?:해외)?(?:승인|취소|결제)))?'),
  '롯데': RegExp(r'롯데카드'),
  '하나': RegExp(r'하나(?:카드|체크)'),
  '우리': RegExp(r'우리(?:카드|체크)'),
  'NH농협': RegExp(r'NH\s?(?:농협)?(?:카드|체크)|농협카드'),
  'BC': RegExp(r'BC카드|비씨카드'),
};

final _status = RegExp(r'승인|취소|결제');
final _tags = RegExp(r'\[(?:Web|국외|국제|해외)발신\]');
final _cumulative = RegExp(r'(?:누적|잔여|잔액|한도|이용가능)[^\d\n]{0,8}[\d,.]+\s*원?');
final _won = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\s?원');
final _foreignCodeFirst = RegExp(r'\b([A-Z]{3})\s?(\d[\d,]*(?:\.\d+)?)');
final _foreignCodeLast = RegExp(r'(\d[\d,]*(?:\.\d+)?)\s?([A-Z]{3})\b');
final _dateTime = RegExp(
  r'(?:(\d{4})[./-](\d{1,2})[./-](\d{1,2})|(\d{1,2})/(\d{1,2}))\s*(\d{1,2}):(\d{2})',
);
final _installment = RegExp(r'\(?(?:일시불|(\d{1,2})개월)\)?');
final _merchantLabel = RegExp(r'(?:이용)?(?:가맹점명?|사용처|이용처)\s*[:：]?\s*([^\n]+)');
final _statusWords = RegExp(
  r'(?:해외\s?)?(?:(?:승인|결제|매출)\s?취소|승인|취소|결제)(?:\s?(?:완료|안내))?',
);
final _names = RegExp(r'[가-힣]\*+[가-힣]*님?|[가-힣]{2,4}님');

/// 알림에 카드사 이름이 있으면 그 이름('신한' 등), 없으면 null.
String? cardIssuerOf(String text) =>
    _issuers.entries.where((e) => e.value.hasMatch(text)).firstOrNull?.key;

double? _number(String? text) =>
    text == null ? null : double.tryParse(text.replaceAll(',', ''));

/// 카드 승인/취소 알림을 읽는다. 카드 알림이 아니거나 못 읽으면 null.
///
/// [title]은 알림 제목(카드사 앱 푸시는 본문에 카드사 이름이 없을 수 있다),
/// [now]는 알림을 받은 시각(문자에 연도·일시가 없을 때 기준).
// ponytail: 필드를 순서와 무관하게 하나씩 떼어내고 남은 글자를 가맹점으로 본다.
// 실제 문자에서 가맹점에 잡음이 섞이면 카드사별 전체 형식 정규식으로 바꾼다.
ParsedCardPayment? parseCardMessage(
  String text, {
  String title = '',
  DateTime? now,
}) {
  now ??= DateTime.now();
  final all = '$title\n$text';
  if (all.contains('(광고)') || all.contains('거절')) return null;
  final issuer = cardIssuerOf(text) ?? cardIssuerOf(title);
  if (issuer == null || !_status.hasMatch(all)) return null;

  var rest = text.replaceAll(_tags, ' ').replaceAll(_cumulative, ' ');
  RegExpMatch? take(RegExp re) {
    final m = re.firstMatch(rest);
    if (m != null) rest = rest.replaceRange(m.start, m.end, ' ');
    return m;
  }

  // 금액: "원"이 있으면 국내 결제, 없으면 "USD 12.30" 같은 해외 결제.
  double? amount;
  var currency = 'KRW';
  final won = take(_won);
  if (won != null) {
    amount = _number(won[1]);
  } else {
    final first = take(_foreignCodeFirst);
    final last = first == null ? take(_foreignCodeLast) : null;
    amount = _number(first?[2] ?? last?[1]);
    currency = first?[1] ?? last?[2] ?? '';
  }
  if (amount == null || amount <= 0 || !amount.isFinite) return null;

  var date = now;
  final d = take(_dateTime);
  if (d != null) {
    final month = int.parse(d[2] ?? d[4]!), day = int.parse(d[3] ?? d[5]!);
    final hour = int.parse(d[6]!), minute = int.parse(d[7]!);
    final year = int.tryParse(d[1] ?? '') ?? now.year;
    if (month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31 &&
        hour < 24 &&
        minute < 60) {
      date = DateTime(year, month, day, hour, minute);
      // 연도가 없는 12/31 문자를 1/1에 읽는 경우
      if (d[1] == null && date.isAfter(now.add(const Duration(days: 1)))) {
        date = DateTime(now.year - 1, month, day, hour, minute);
      }
    }
  }

  final months = int.tryParse(take(_installment)?[1] ?? '') ?? 0;

  final header = RegExp(
    '(?:${_issuers[issuer]!.pattern})'
    r'(?:\s?\(?[\d*]{4}\)?(?![\d*]))?',
  );
  final merchant =
      (_merchantLabel.firstMatch(rest)?[1] ??
              rest
                  .replaceAll(header, ' ')
                  .replaceAll(_statusWords, ' ')
                  .replaceAll(_names, ' ')
                  .replaceAll(RegExp(r'체크|신용|\(\s*\)|\[\s*\]'), ' '))
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^[\s:：·,\-/\])]+|[\s:：·,\-/\[(]+$'), '');
  if (merchant.isEmpty) return null;

  return ParsedCardPayment(
    issuer: issuer,
    merchant: merchant,
    amount: amount,
    currency: currency,
    date: date,
    cancelled: all.contains('취소'),
    installmentMonths: months,
  );
}
