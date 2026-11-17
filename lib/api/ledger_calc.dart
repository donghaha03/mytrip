import '../models/expense.dart';
import '../models/trip.dart';
import 'rate_api.dart';

/// 장부 계산 (순수 함수 - Firebase 없이 테스트 가능)
class LedgerCalc {
  LedgerCalc._();

  /// 총 사용액 (원)
  static double spentKrw(List<Expense> list) =>
      list.fold(0.0, (s, e) => s + e.amountKrw);

  /// 남은 예산 (원). 음수면 초과
  static double remainingKrw(Trip trip, List<Expense> list) =>
      trip.budget - spentKrw(list);

  /// 남은 예산을 현지 통화로 (현재 환율 기준)
  static double remainingLocal(Trip trip, List<Expense> list) =>
      RateApi.fromKrw(remainingKrw(trip, list), trip.currency);

  /// 예산 사용 비율 0.0 ~ 1.0 (진행 바용)
  static double usedRatio(Trip trip, List<Expense> list) =>
      trip.budget <= 0 ? 0 : (spentKrw(list) / trip.budget).clamp(0.0, 1.0);

  static bool isOverBudget(Trip trip, List<Expense> list) =>
      remainingKrw(trip, list) < 0;

  /// 카테고리별 사용액 합계 (원)
  static Map<String, double> byCategory(List<Expense> list) {
    final m = <String, double>{};
    for (final e in list) {
      m[e.category] = (m[e.category] ?? 0) + e.amountKrw;
    }
    return m;
  }

  /// 최근 결제가 위로 오도록 정렬한 새 리스트
  static List<Expense> recentFirst(List<Expense> list) =>
      [...list]..sort((a, b) => b.date.compareTo(a.date));
}
