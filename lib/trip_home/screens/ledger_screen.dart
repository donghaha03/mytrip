import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/expense_tile.dart';
import '../widgets/quick_converter.dart';
import '../widgets/rate_info_tooltip.dart';
import '../widgets/screen_top_bar.dart';
import 'expense_form_screen.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key, required this.trip});

  final Trip trip;

  void _edit(BuildContext context, [Expense? expense]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseFormScreen(trip: trip, expense: expense),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([tripStore, RateApi.changes]),
    builder: (context, _) {
      final available = RateApi.quotedKrw(trip.country.currency) > 0;
      final groups = <DateTime, List<Expense>>{};
      for (final e in trip.expensesNewestFirst) {
        final day = DateTime(e.date.year, e.date.month, e.date.day);
        (groups[day] ??= []).add(e);
      }
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenTopBar(
                title: '여행 장부',
                trailing: Text(
                  '${trip.expenses.length}건',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${trip.country.flag} ${trip.name}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          currentRateLabel(trip.country),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        RateInfoButton(currency: trip.country.currency),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '사용한 금액',
                            style: TextStyle(color: AppColors.onPrimaryMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            available ? formatWon(trip.spentKrw) : '환율 없음',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: available ? trip.spentRatio : 0,
                              minHeight: 6,
                              backgroundColor: AppColors.progressTrack,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              _Figure(
                                label: '예산',
                                value: formatWon(trip.budgetKrw),
                              ),
                              _Figure(
                                label: trip.remainKrw < 0 ? '예산 초과' : '남은 금액',
                                value: available
                                    ? formatWon(trip.remainKrw.abs())
                                    : '환율 없음',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(height: 12),
                            Text('아직 기록한 지출이 없어요'),
                            SizedBox(height: 6),
                            Text(
                              '첫 지출을 기록해보세요',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final group in groups.entries) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatShortDateWithWeekday(group.key),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            available
                                ? formatWon(trip.spentKrwOf(group.value))
                                : '환율 없음',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < group.value.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                              ExpenseTile(
                                trip: trip,
                                expense: group.value[i],
                                showDate: false,
                                onTap: () => _edit(context, group.value[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '지출 기록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.onPrimaryMuted),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    ],
  );
}
