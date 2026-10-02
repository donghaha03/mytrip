import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../models/country.dart';
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
    final currency = e.currencyOf(trip);
    final amount = e.status.countsAsSpending ? e.amount : 0;
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
                    const SizedBox(height: 3),
                    Text(
                      '${e.paymentMethod?.label ?? '결제수단 미지정'}${e.isTaxFree ? ' · 면세' : ''}'
                      '${e.source == 'demo-card'
                          ? ' · 테스트'
                          : e.isImported
                          ? ' · 자동'
                          : ''}'
                      '${e.status != ExpenseStatus.approved ? ' · ${e.status.label}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      !e.status.countsAsSpending ||
                              RateApi.quotedKrw(currency) > 0
                          ? formatWon(e.krwOf(trip))
                          : '환율 없음',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${countryByCode(currency)?.formatForeign(amount) ?? formatNumber(amount.truncate())} $currency',
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
