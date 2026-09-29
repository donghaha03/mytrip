import 'country.dart';

class Expense {
  Expense({
    required this.id,
    required this.icon,
    required this.place,
    required this.amount,
    required this.date,
    this.category = '기타',
  });

  final String id;
  final String icon; // 카테고리 대표 아이콘 (이모지)
  final String place; // 사용처
  final double amount; // 현지 통화 기준 사용 금액
  final DateTime date; // 기록 시각 (시스템 시간)
  final String category;
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

  double get spentForeign =>
      expenses.fold<double>(0, (sum, e) => sum + e.amount);

  double get spentKrw => country.toKrw(spentForeign);

  double get remainKrw => budgetKrw - spentKrw;

  double get budgetForeign =>
      budgetKrw * country.unitAmount / country.krwPerUnit;

  double get remainForeign =>
      remainKrw * country.unitAmount / country.krwPerUnit;

  /// 0.0 ~ 1.0 (예산 대비 지출 비율)
  double get spentRatio =>
      budgetKrw == 0 ? 0 : (spentKrw / budgetKrw).clamp(0.0, 1.0);

  /// 어제 하루 동안 쓴 금액 (원화). 메인 화면 증감 배지에 사용.
  double get yesterdaySpentKrw {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final total = expenses
        .where((e) =>
            e.date.year == yesterday.year &&
            e.date.month == yesterday.month &&
            e.date.day == yesterday.day)
        .fold<double>(0, (sum, e) => sum + e.amount);
    return country.toKrw(total);
  }

  /// 최근 기록이 위로 오도록 정렬된 지출 목록
  List<Expense> get expensesNewestFirst {
    final sorted = [...expenses]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
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
