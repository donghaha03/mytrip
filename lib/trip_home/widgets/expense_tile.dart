import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 홈 요약과 전체 장부에서 같은 금액·표시 형식을 사용한다.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.trip,
    required this.expense,
    this.onTap,
    this.showDate = true,
  });

  final Trip trip;
  final Expense expense;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final time =
        '${e.date.hour.toString().padLeft(2, '0')}:'
        '${e.date.minute.toString().padLeft(2, '0')}';
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(e.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${e.category} · ${showDate ? formatShortDateWithWeekday(e.date) : time}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      RateApi.quotedKrw(trip.country.currency) > 0
                          ? formatWon(
                              RateApi.toKrw(e.amount, trip.country.currency),
                            )
                          : '환율 없음',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      trip.country.formatForeign(e.amount),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
