import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/spending_summary.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A light inset keeps category colors legible on the blue summary cards.
class BudgetProgressPanel extends StatefulWidget {
  const BudgetProgressPanel({super.key, required this.trip});
  final Trip trip;
  @override
  State<BudgetProgressPanel> createState() => _BudgetProgressPanelState();
}

class _BudgetProgressPanelState extends State<BudgetProgressPanel> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final summary = SpendingSummary(widget.trip);
    final percent = widget.trip.budgetKrw <= 0
        ? 0
        : summary.netKrw * 100 ~/ widget.trip.budgetKrw;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '예산 사용',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                summary.available ? '$percent%' : '—',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CategoryBudgetBar(trip: widget.trip, height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              expanded: _expanded,
              child: TextButton.icon(
                key: const ValueKey('spending-categories-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _expanded ? '접기' : '더보기',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: !summary.available
                  ? const Text('환율을 확인하면 구성비를 볼 수 있어요')
                  : summary.positiveKrw == 0
                  ? const Text('아직 표시할 지출이 없어요')
                  : Column(
                      children: [
                        for (final entry in summary.sorted)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: categoryColor(entry.key),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${entry.key} ${(summary.share(entry.key) * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    formatWon(entry.value),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class CategoryBudgetBar extends StatelessWidget {
  const CategoryBudgetBar({
    super.key,
    required this.trip,
    this.height = 8,
    this.track = AppColors.border,
  });
  final Trip trip;
  final double height;
  final Color track;
  @override
  Widget build(BuildContext context) {
    final summary = SpendingSummary(trip);
    final ratio = summary.budgetRatio(trip.budgetKrw);
    final percent = trip.budgetKrw <= 0
        ? 0
        : summary.netKrw * 100 ~/ trip.budgetKrw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: summary.available
              ? '예산 소진율 $percent퍼센트. 색상은 카테고리별 지출'
              : '환율이 없어 예산 소진율을 계산할 수 없어요',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: height,
              child: LayoutBuilder(
                builder: (_, constraints) => Row(
                  children: [
                    for (final category in summary.sorted)
                      SizedBox(
                        width:
                            constraints.maxWidth *
                            ratio *
                            summary.share(category.key),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: categoryColor(category.key),
                            border: Border(
                              right: BorderSide(
                                color: AppColors.white,
                                width: .7,
                              ),
                            ),
                          ),
                          child: SizedBox(height: height),
                        ),
                      ),
                    Expanded(
                      child: ColoredBox(
                        color: track,
                        child: SizedBox(height: height),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CategoryPie extends StatelessWidget {
  const CategoryPie({super.key, required this.summary});
  final SpendingSummary summary;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '카테고리별 양수 지출 구성비. 아래 목록에서 금액과 비율을 확인하세요',
    child: SizedBox(
      height: 220,
      child: Center(
        child: SizedBox.square(
          dimension: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PiePainter(summary)),
              ),
              Container(
                width: 115,
                height: 115,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '지출 구성',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        formatWon(summary.positiveKrw),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.summary);
  final SpendingSummary summary;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var angle = -math.pi / 2;
    for (final category in summary.sorted) {
      final sweep = summary.share(category.key) * math.pi * 2;
      canvas.drawArc(
        rect,
        angle,
        sweep,
        true,
        Paint()..color = categoryColor(category.key),
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => true;
}
