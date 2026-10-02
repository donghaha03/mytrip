import '../../api/api.dart';
import 'country.dart';

const expenseCategoryIcons = {
  '식비': '🍜',
  '교통': '🚃',
  '숙박': '🏨',
  '쇼핑': '🛍',
  '관광': '📷',
  '기타': '💸',
};

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

class Expense {
  Expense({
    required this.id,
    required this.icon,
    required this.place,
    required this.amount,
    required this.date,
    this.category = '기타',
    this.paymentMethod,
    this.isTaxFree = false,
    this.currency,
    this.memo = '',
    this.recordedQuote,
    this.source,
    this.status = ExpenseStatus.approved,
    this.originalAmount,
  });

  final String id;
  final String icon; // 카테고리 대표 아이콘 (이모지)
  final String place; // 사용처
  final double amount; // 현지 통화 기준 실제 결제액. 면세 금액을 다시 차감하지 않는다.
  final DateTime date; // 기록 시각 (시스템 시간)
  final String category;
  final PaymentMethod? paymentMethod; // 기존 기록은 미지정으로 유지한다.
  final bool isTaxFree;
  final String? currency; // 이전 기록은 여행 통화를 따른다.
  final String memo;
  final int? recordedQuote; // 기록 당시 표시 환율. 합계는 현재 환율로 계산한다.
  final String? source; // demo-card / codef. 직접 입력한 기록은 null.
  final ExpenseStatus status;
  final double? originalAmount;

  bool get isImported => source != null;
  String currencyOf(Trip trip) => currency ?? trip.country.currency;
  int krwOf(Trip trip) =>
      status.countsAsSpending ? RateApi.toKrw(amount, currencyOf(trip)) : 0;
}

class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.country,
    required this.start,
    required this.end,
    required this.budgetKrw,
    List<Expense>? expenses,
  }) : expenses = expenses ?? [];

  final String id;
  String name;
  Country country;
  DateTime start;
  DateTime end;
  int budgetKrw;
  final List<Expense> expenses;

  /// 여행 종료일이 지났으면 완료 처리 -> 리스트에서 "여행완료" 도장
  bool get isCompleted {
    final today = DateTime.now();
    final endOfTrip = DateTime(end.year, end.month, end.day);
    return endOfTrip.isBefore(DateTime(today.year, today.month, today.day));
  }

  int get spentForeign => RateApi.fromKrw(spentKrw, country.currency);

  bool ratesAvailable(Iterable<Expense> entries) => entries.every(
    (e) =>
        !e.status.countsAsSpending || RateApi.quotedKrw(e.currencyOf(this)) > 0,
  );

  /// 항목별 정수 환산액을 더한다. 목록·날짜별 합계·홈이 같은 값을 쓴다.
  int spentKrwOf(Iterable<Expense> entries) =>
      entries.fold<int>(0, (sum, e) => sum + e.krwOf(this));

  int get spentKrw => spentKrwOf(expenses);

  int get remainKrw => budgetKrw - spentKrw;

  int get budgetForeign => RateApi.fromKrw(budgetKrw, country.currency);

  int get remainForeign => RateApi.fromKrw(remainKrw, country.currency);

  /// 0.0 ~ 1.0 (예산 대비 지출 비율)
  double get spentRatio =>
      budgetKrw == 0 ? 0 : (spentKrw / budgetKrw).clamp(0.0, 1.0);

  /// 어제 하루 동안 쓴 금액 (원화). 메인 화면 증감 배지에 사용.
  int get yesterdaySpentKrw {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return spentKrwOf(
      expenses.where(
        (e) =>
            e.date.year == yesterday.year &&
            e.date.month == yesterday.month &&
            e.date.day == yesterday.day,
      ),
    );
  }

  /// 최근 기록이 위로 오도록 정렬된 지출 목록
  List<Expense> get expensesNewestFirst {
    final sorted = [...expenses]
      ..sort((a, b) {
        final date = b.date.compareTo(a.date);
        return date == 0 ? a.id.compareTo(b.id) : date;
      });
    return sorted;
  }

  String dayLabel(DateTime at) {
    DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
    final today = day(at);
    if (today.isAfter(day(end))) return '여행 완료';
    final days = today.difference(day(start)).inDays;
    return days < 0
        ? 'D${days.toString()}'
        : days == 0
        ? 'D-day'
        : 'D+$days';
  }

  String get dateRangeLabel {
    String f(DateTime d) =>
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    return '${f(start)} - ${f(end)}';
  }

  /// "4박 5일"
  String get durationLabel {
    final nights = end.difference(start).inDays;
    return '$nights박 ${nights + 1}일';
  }
}
