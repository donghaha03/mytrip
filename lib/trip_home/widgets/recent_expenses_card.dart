import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'expense_tile.dart';

/// 여행 홈의 "최근 지출" 카드.
///
/// 최근 7일 막대 + 마지막 지출 3건만 보여주는 **요약**이다. 전체 목록과 기록
/// 입력은 장부 몫이라, 더 보려면 [onOpenLedger] 로 장부에 넘긴다.
///
/// 막대는 한 가지 색만 쓰는 단일 계열이라 범례가 필요 없다. 고른 막대만 진한
/// 파랑으로 두고 나머지는 연하게 — 색이 순위를 뜻하지 않고 "지금 보고 있는 날"
/// 이라는 상태만 나타낸다.
class RecentExpensesCard extends StatefulWidget {
  const RecentExpensesCard({
    super.key,
    required this.trip,
    required this.now,
    required this.onOpenLedger,
    required this.onOpenOverview,
    required this.onAddExpense,
  });

  final Trip trip;
  final DateTime now;
  final VoidCallback onOpenLedger;
  final VoidCallback onOpenOverview;
  final VoidCallback onAddExpense;

  @override
  State<RecentExpensesCard> createState() => _RecentExpensesCardState();
}

class _RecentExpensesCardState extends State<RecentExpensesCard> {
  /// 막대에서 고른 날 (기본: 오늘 = 마지막 칸)
  int _selected = 6;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final days = dailySpending(trip, widget.now);
    final hasAny = trip.expenses.isNotEmpty;
    final recent = trip.expensesNewestFirst.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '최근 지출',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              if (hasAny)
                Text(
                  '${trip.expenses.length}건',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              const Spacer(),
              _SummaryLink(label: '지출보기', onTap: widget.onOpenLedger),
            ],
          ),
          if (!hasAny)
            _Empty(onAdd: widget.onAddExpense)
          else ...[
            const SizedBox(height: 10),
            if (!trip.ratesAvailable(trip.expenses))
              const Text('환율 없음')
            else
              _WeekBars(
                trip: trip,
                days: days,
                selected: _selected,
                onSelect: (i) => setState(() => _selected = i),
              ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: _SummaryLink(label: '한눈에 보기', onTap: widget.onOpenOverview),
          ),
          if (hasAny) ...[
            Container(height: 1, color: AppColors.border),
            for (final e in recent)
              ExpenseTile(trip: trip, expense: e, interactive: false),
          ],
        ],
      ),
    );
  }
}

class _SummaryLink extends StatelessWidget {
  const _SummaryLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      textStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const Icon(Icons.chevron_right_rounded, size: 16),
      ],
    ),
  );
}

/// 오늘까지 7일치 (날짜, 원화 합계). 인덱스 6 이 오늘.
List<({DateTime day, int krw})> dailySpending(Trip t, DateTime now) {
  DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
  final today = dayOf(now);
  return List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    return (
      day: day,
      krw: t.spentKrwOf(t.expenses.where((e) => dayOf(e.date) == day)),
    );
  });
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({
    required this.trip,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final Trip trip;
  final List<({DateTime day, int krw})> days;
  final int selected;
  final ValueChanged<int> onSelect;

  /// 가장 큰 날의 막대 높이
  static const _maxHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(0, (m, d) => d.krw > m ? d.krw : m);
    final picked = days[selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 고른 날만 값을 쓴다 (모든 막대에 숫자를 붙이지 않는다)
        Row(
          children: [
            Text(
              formatShortDateWithWeekday(picked.day),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              picked.krw == 0 ? '지출 없음' : formatWon(picked.krw),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: picked.krw == 0
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 높이를 고정하지 않는다 — 가장 높은 막대 + 요일 글자 높이에 맞춰
        // 저절로 정해지게 둬야 글꼴이 달라져도 안 넘친다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: _Bar(
                  ratio: max == 0 ? 0 : (days[i].krw / max).clamp(0.0, 1.0),
                  day: days[i].day,
                  isSelected: i == selected,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.ratio,
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final double ratio;
  final DateTime day;
  final bool isSelected;
  final VoidCallback onTap;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    // 0원인 날도 눌러서 고를 수 있게 바닥에 얇은 자국을 남긴다
    final height = ratio == 0 ? 3.0 : 6 + ratio * (_WeekBars._maxHeight - 6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            // 막대 사이 2px 여백
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: ratio == 0
                    ? AppColors.border
                    : isSelected
                    ? AppColors.primary
                    : AppColors.primaryLight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4), // 데이터 끝만 둥글게
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _weekdays[day.weekday - 1],
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      child: Column(
        children: [
          const Text(
            '아직 기록한 지출이 없어요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    '첫 지출 기록하기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
