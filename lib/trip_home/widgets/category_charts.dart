import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/spending_summary.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: summary.available
              ? '예산 소진율 ${(ratio * 100).toStringAsFixed(1)}퍼센트. 색상은 양수 지출의 카테고리 구성비'
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
                        child: ColoredBox(
                          color: categoryColor(category.key),
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
