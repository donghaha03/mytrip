import '../data/rates.dart';
import '../models/trip.dart';
import 'card_message_parser.dart';

/// 카드 알림으로 만든 지출의 `Expense.source` 값.
const cardNotificationSource = 'card_notification';

/// 같은 결제로 보는 시각 차이.
const _window = Duration(minutes: 5);

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s'), '');

/// 문자·알림톡·앱 푸시마다 가맹점 표기가 조금씩 달라 포함 관계로 비교한다.
bool _sameMerchant(String a, String b) {
  final x = _norm(a), y = _norm(b);
  return x.isNotEmpty && y.isNotEmpty && (x.contains(y) || y.contains(x));
}

bool _sameAmount(double a, double b) => (a - b).abs() < 0.005;

bool _samePayment(ParsedCardPayment a, ParsedCardPayment b) =>
    a.cancelled == b.cancelled &&
    a.currency == b.currency &&
    _sameAmount(a.amount, b.amount) &&
    a.date.difference(b.date).abs() <= _window &&
    _sameMerchant(a.merchant, b.merchant);

bool _sameAsExpense(Expense e, ParsedCardPayment p) =>
    e.currency == p.currency &&
    _sameAmount(e.amount, p.amount) &&
    _sameMerchant(e.place, p.merchant);

/// 큐 안의 중복(같은 결제가 문자·알림톡·푸시로 여러 번 온 경우)과
/// 이미 장부에 있는 지출(취소 알림은 이미 취소 처리된 지출)을 걸러낸다.
List<ParsedCardPayment> dedupeCardPayments(
  Iterable<ParsedCardPayment> payments,
  Iterable<Expense> saved,
) {
  final result = <ParsedCardPayment>[];
  for (final p in payments) {
    if (result.any((kept) => _samePayment(kept, p))) continue;
    final recorded = saved.any(
      (e) =>
          _sameAsExpense(e, p) &&
          (p.cancelled
              ? e.status == ExpenseStatus.cancelled
              : e.date.difference(p.date).abs() <= _window),
    );
    if (!recorded) result.add(p);
  }
  return result;
}

/// 취소 알림과 짝이 되는 기존 지출(같은 금액·가맹점의 가장 최근 승인 건).
/// 없으면 null. 찾아도 자동으로 바꾸지 않고 화면에서 제안만 한다.
Expense? findCancelTarget(ParsedCardPayment p, Iterable<Expense> saved) {
  Expense? best;
  for (final e in saved) {
    if (e.status != ExpenseStatus.approved ||
        !_sameAsExpense(e, p) ||
        e.date.isAfter(p.date.add(_window))) {
      continue;
    }
    if (best == null || e.date.isAfter(best.date)) best = e;
  }
  return best;
}

// ponytail: 가맹점 이름 키워드로만 추정한다. 틀리면 저장 뒤 수정 화면에서 고친다.
const _categoryKeywords = {
  '숙박': r'(호텔|hotel|모텔|리조트|resort|게스트하우스|hostel|숙박|펜션|에어비앤비|airbnb)',
  '교통':
      r'(택시|taxi|버스|지하철|철도|코레일|ktx|srt|항공|airline|airways|주유|주차|하이패스|티머니|metro|railway|uber|grab)',
  '관광': r'(입장|매표|박물관|미술관|museum|전망대|놀이공원|투어|tour|ticket)',
  '식비':
      r'(스타벅스|starbucks|카페|cafe|coffee|커피|식당|치킨|피자|버거|맥도날드|베이커리|파리바게|뚜레쥬르|라멘|스시|분식|김밥|국밥|restaurant|편의점|gs25|세븐일레븐|lawson|familymart|배달)',
  '쇼핑':
      r'(마트|백화점|면세|duty free|올리브영|다이소|아울렛|쇼핑|mall|돈키호테|유니클로|쿠팡)',
};

/// 가맹점 이름으로 카테고리를 추정한다. 못 정하면 `기타`.
String guessCardCategory(String merchant) {
  for (final entry in _categoryKeywords.entries) {
    if (RegExp(entry.value, caseSensitive: false).hasMatch(merchant)) {
      return entry.key;
    }
  }
  return '기타';
}

/// 승인 알림으로 만드는 지출 초안. 저장은 `TripStore.saveExpense`가 한다
/// (환율은 저장할 때 API가 현재 환율로 다시 채운다).
Expense draftExpense(ParsedCardPayment p) {
  final category = guessCardCategory(p.merchant);
  return Expense(
    id: '',
    category: category,
    place: p.merchant,
    amount: p.amount,
    currency: p.currency,
    rate: RateApi.krwPer(p.currency),
    date: p.date,
    icon: expenseCategoryIcons[category]!,
    paymentMethod: PaymentMethod.card,
    memo: p.installmentMonths > 0
        ? '${p.issuer}카드 알림 · ${p.installmentMonths}개월 할부'
        : '${p.issuer}카드 알림',
    source: cardNotificationSource,
    status: ExpenseStatus.approved,
  );
}

/// 결제일이 여행 기간(날짜 기준) 밖인가.
bool outsideTrip(Trip trip, DateTime date) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final d = day(date);
  return d.isBefore(day(trip.start)) || d.isAfter(day(trip.end));
}
