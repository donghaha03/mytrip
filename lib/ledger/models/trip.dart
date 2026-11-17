import '../../api/api.dart' as api;
import '../data/rates.dart';
import 'country.dart';

export '../../models/expense.dart';

const expenseCategoryIcons = {
  '식비': '🍜',
  '교통': '🚃',
  '숙박': '🏨',
  '쇼핑': '🛍',
  '관광': '📷',
  '기타': '💸',
};

extension LedgerExpense on api.Expense {
  String currencyOf(Trip trip) => currency;
  int krwOf(Trip trip) => amountKrw.truncate();
}

class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.country,
    required this.start,
    required this.end,
    required this.budgetKrw,
    List<api.Expense>? expenses,
  }) : expenses = expenses ?? [];

  final String id;
  String name;
  Country country;
  DateTime start;
  DateTime end;
  int budgetKrw;
  final List<api.Expense> expenses;

  /// 여행 종료일이 지났으면 완료 처리 -> 리스트에서 "여행완료" 도장
  bool get isCompleted {
    final today = DateTime.now();
    final endOfTrip = DateTime(end.year, end.month, end.day);
    return endOfTrip.isBefore(DateTime(today.year, today.month, today.day));
  }

  int get spentForeign => RateApi.fromKrw(spentKrw, country.currency);

  bool ratesAvailable(Iterable<api.Expense> entries) => entries.every(
    (e) => !e.status.countsAsSpending || e.amount == 0 || e.rate > 0,
  );

  /// 팀의 기록 당시 환율로 합산하고 원 미만은 표시에서 버린다.
  int spentKrwOf(Iterable<api.Expense> entries) =>
      api.LedgerCalc.spentKrw(entries.toList()).truncate();

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
  List<api.Expense> get expensesNewestFirst {
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
