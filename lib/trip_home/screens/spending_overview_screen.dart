import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../data/trip_store.dart';
import '../models/spending_summary.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/category_charts.dart';
import '../widgets/expense_tile.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/quick_converter.dart';
import '../models/country.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';

class SpendingOverviewScreen extends StatelessWidget {
  const SpendingOverviewScreen({super.key, required this.trip});
  final Trip trip;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([tripStore, RateApi.changes]),
    builder: (context, _) {
      final summary = SpendingSummary(trip);
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ScreenTopBar(
                title: '지출 한눈에 보기',
                trailing: IconButton(
                  tooltip: '지출 추가',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExpenseFormScreen(trip: trip),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      trip.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '집계: 이 여행에 기록한 전체 기간',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      summary.available
                          ? '총 순지출 ${formatWon(summary.netKrw)}'
                          : '환율 확인 필요',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final entry
                        in summary.unconvertedCancellations.entries)
                      Text(
                        '${entry.key} 취소·부분취소 ${formatNumber(entry.value.truncate())} (환율 없음 · 순지출에서 제외)',
                      ),
                    if (!summary.available) ...[
                      Text(
                        '${summary.missingCurrencies.join(', ')} 환율이 없어 통화별로 표시해요. 서로 다른 통화는 합산하지 않아요.',
                      ),
                      for (final entry
                          in summary.originalCurrencyTotals.entries)
                        Text(
                          '${entry.key} ${formatNumber(entry.value.truncate())}',
                        ),
                    ] else ...[
                      if (summary.refundsKrw > 0)
                        Text(
                          '양수 지출 ${formatWon(summary.positiveKrw)} · 환불 조정 −${formatWon(summary.refundsKrw)}',
                        ),
                      if (summary.cancellationsKrw > 0)
                        Text(
                          '취소·부분취소 ${formatWon(summary.cancellationsKrw)} (순지출에서 이미 제외)',
                        ),
                      const SizedBox(height: 12),
                      if (summary.positiveKrw > 0) ...[
                        CategoryPie(summary: summary),
                        const Text(
                          '구성비는 취소 후 남은 양수 지출 기준이에요. 음수 환불은 차트에 넣지 않아요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        for (final entry in summary.sorted)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.circle,
                              color: categoryColor(entry.key),
                              size: 14,
                            ),
                            title: Text(entry.key),
                            subtitle: Text(
                              '${(summary.share(entry.key) * 100).toStringAsFixed(1)}%',
                            ),
                            trailing: Text(
                              formatWon(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            trip.expenses.isEmpty
                                ? '기록한 지출이 없어요'
                                : '차트에 표시할 양수 지출이 없어요',
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '원화 환산: 상단과 같은 현재 환율 · 입력·결과 소수점 버림${RateApi.updatedAt == null ? '' : ' · 기준일 ${formatDate(RateApi.updatedAt!)}'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    for (final code
                        in trip.expenses
                            .where((e) => e.status.countsAsSpending)
                            .map((e) => e.currencyOf(trip))
                            .toSet())
                      Text(
                        countryByCode(code) == null
                            ? '$code 환율 없음'
                            : currentRateLabel(countryByCode(code)!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      '상세 지출 ${trip.expenses.length}건',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final e in trip.expensesNewestFirst)
                      ExpenseTile(
                        trip: trip,
                        expense: e,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExpenseDetailScreen(
                              trip: trip,
                              expenseId: e.id,
                            ),
                          ),
                        ),
                      ),
                    if (trip.expenses.isEmpty)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExpenseFormScreen(trip: trip),
                          ),
                        ),
                        child: const Text('지출 기록하기'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
