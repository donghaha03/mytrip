import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../models/country.dart';
import '../models/trip.dart';
import '../models/spending_summary.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../screens/expense_detail_screen.dart';
import '../screens/expense_form_screen.dart';
import 'swipe_actions.dart';

/// 홈 요약과 전체 장부에서 같은 금액·표시 형식을 사용한다.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.trip,
    required this.expense,
    this.onTap,
    this.showDate = true,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final Trip trip;
  final Expense expense;
  final VoidCallback? onTap;
  final bool showDate;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final currency = e.currencyOf(trip);
    final amount = e.status.countsAsSpending ? e.amount : 0;
    final time =
        '${e.date.hour.toString().padLeft(2, '0')}:'
        '${e.date.minute.toString().padLeft(2, '0')}';
    void edit() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseFormScreen(trip: trip, expense: e),
      ),
    );
    return SwipeActions(
      key: ValueKey('expense-swipe-${trip.id}-${e.id}'),
      label: '${e.place} 지출',
      onEdit: edit,
      onDelete: () async {
        try {
          await deleteExpenseWithConfirmation(context, trip, e);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('삭제하지 못했어요. 기록을 유지했으니 다시 시도해주세요.')),
            );
          }
        }
      },
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap:
                onTap ??
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ExpenseDetailScreen(trip: trip, expenseId: e.id),
                  ),
                ),
            onLongPress: edit,
            highlightColor: AppColors.primaryLight,
            splashColor: AppColors.primaryLight,
            hoverColor: AppColors.primarySoft,
            focusColor: AppColors.primarySoft,
            child: Padding(
              padding: padding,
              child: Row(
                children: [
                  Text(e.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 5),
                  Icon(Icons.circle, size: 7, color: categoryColor(e.category)),
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
                          '${normalizedCategory(e.category)} · ${showDate ? formatShortDateWithWeekday(e.date) : time}',
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
                  Expanded(
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
        ),
      ),
    );
  }
}
