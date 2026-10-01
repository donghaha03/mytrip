import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../../api/api.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_sheet.dart';

enum TodayPhase {
  /// 아직 출발 전 — 여행 전체 일수로 나눈다
  beforeTrip,

  /// 여행 중 — 오늘 포함 남은 날로 나눈다
  during,

  /// 여행이 끝났다
  finished,

  /// 예산을 이미 다 썼다
  overBudget,
}

/// "오늘 얼마 쓰면 좋은지" 계산 결과.
@immutable
class TodayBudget {
  const TodayBudget({
    required this.phase,
    required this.allowanceKrw,
    required this.daysLeft,
    required this.spentTodayKrw,
    required this.remainKrw,
  });

  final TodayPhase phase;

  /// 오늘(또는 출발 후 하루) 쓰기 좋은 금액
  final double allowanceKrw;

  /// 나눈 날 수 (오늘 포함)
  final int daysLeft;

  /// 오늘 이미 쓴 금액 (여행 중일 때만 의미 있음)
  final double spentTodayKrw;

  /// 지금 남은 예산 (음수면 초과)
  final double remainKrw;

  /// 오늘 쓸 수 있는 금액 중 아직 남은 것 (음수면 오늘 몫을 넘김)
  double get leftTodayKrw => allowanceKrw - spentTodayKrw;
}

/// 남은 예산을 남은 날로 나눠서 오늘 몫을 구한다.
///
/// 여행 중이면 "오늘 아침 기준" 으로 나눈다 — 지금 남은 돈으로 나누면 오늘 쓸수록
/// 오늘 몫이 같이 줄어드는 이상한 숫자가 되기 때문. 그래서
///   오늘 몫 = (지금 남은 예산 + 오늘 쓴 돈) / 오늘 포함 남은 날
/// 로 구하고, 오늘 쓴 돈을 빼서 "오늘 남은 금액" 을 따로 보여준다.
TodayBudget todayBudget(Trip t, DateTime now) {
  DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final today = day(now);
  final start = day(t.start);
  final end = day(t.end);
  final remain = t.remainKrw;

  if (today.isAfter(end)) {
    return TodayBudget(
      phase: TodayPhase.finished,
      allowanceKrw: 0,
      daysLeft: 0,
      spentTodayKrw: 0,
      remainKrw: remain,
    );
  }

  final before = today.isBefore(start);
  final daysLeft = before
      ? end.difference(start).inDays + 1
      : end.difference(today).inDays + 1;

  final spentToday = before
      ? 0.0
      : t.country.toKrw(
          t.expenses
              .where((e) => day(e.date) == today)
              .fold<double>(0, (s, e) => s + e.amount),
        );
  final remainThisMorning = remain + spentToday;

  if (remainThisMorning <= 0) {
    return TodayBudget(
      phase: TodayPhase.overBudget,
      allowanceKrw: 0,
      daysLeft: daysLeft,
      spentTodayKrw: spentToday,
      remainKrw: remain,
    );
  }

  return TodayBudget(
    phase: before ? TodayPhase.beforeTrip : TodayPhase.during,
    allowanceKrw: remainThisMorning / daysLeft,
    daysLeft: daysLeft,
    spentTodayKrw: spentToday,
    remainKrw: remain,
  );
}

/// 여행 홈의 "오늘 예산" 아이콘을 누르면 뜨는 시트.
class TodayBudgetSheet extends StatelessWidget {
  const TodayBudgetSheet({super.key, required this.trip, required this.now});

  final Trip trip;
  final DateTime now;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: RateApi.changes,
    builder: (context, _) => _buildSheet(context),
  );

  Widget _buildSheet(BuildContext context) {
    final b = todayBudget(trip, now);
    final c = trip.country;
    final rate = RateApi.krwPer(c.currency);

    final (String caption, String headline) = switch (b.phase) {
      TodayPhase.beforeTrip => (
        '출발하면 하루에 이만큼 쓰면 예산에 딱 맞아요',
        '하루 ${formatWon(b.allowanceKrw)}',
      ),
      TodayPhase.during => (
        '오늘 포함 ${b.daysLeft}일 남았어요',
        formatWon(b.allowanceKrw),
      ),
      TodayPhase.finished => ('여행이 끝났어요', '—'),
      TodayPhase.overBudget => ('예산을 다 썼어요', '0원'),
    };

    return AppSheet(
      title: b.phase == TodayPhase.beforeTrip ? '하루 예산' : '오늘 예산',
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (b.allowanceKrw > 0) ...[
                const SizedBox(height: 2),
                Text(
                  rate <= 0
                      ? '환율 없음'
                      : '≈ ${c.formatForeign(RateApi.fromKrw(b.allowanceKrw, c.currency))}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (b.phase == TodayPhase.beforeTrip || b.phase == TodayPhase.during)
          _Row(
            '계산',
            '남은 ${formatWon(b.remainKrw + b.spentTodayKrw)} ÷ ${b.daysLeft}일',
          ),
        if (b.phase == TodayPhase.during) ...[
          _Row('오늘 쓴 금액', formatWon(b.spentTodayKrw)),
          _Row(
            b.leftTodayKrw >= 0 ? '오늘 남은 금액' : '오늘 몫 초과',
            formatWon(b.leftTodayKrw.abs()),
            warn: b.leftTodayKrw < 0,
          ),
        ],
        if (b.phase == TodayPhase.finished)
          _Row(
            b.remainKrw >= 0 ? '남은 예산' : '초과',
            formatWon(b.remainKrw.abs()),
            warn: b.remainKrw < 0,
          ),
        if (b.phase == TodayPhase.overBudget)
          _Row('초과', formatWon(b.remainKrw.abs()), warn: true),
        const SizedBox(height: 16),
        SheetPrimaryButton(
          label: '확인',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: warn ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
