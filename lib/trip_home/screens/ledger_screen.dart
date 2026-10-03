import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/ledger_filters_sheet.dart';
import '../widgets/quick_converter.dart';
import '../widgets/rate_info_tooltip.dart';
import '../widgets/screen_top_bar.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String? _payment;
  bool _categories = false;
  bool _byAmount = false;
  bool? _imported;
  Trip get trip => widget.trip;

  String get _filterLabel => [
    _payment == null
        ? '전체'
        : _payment == 'card'
        ? '카드'
        : _payment == 'cash'
        ? '현금'
        : '미지정',
    _categories ? '카테고리별' : '날짜별',
    if (_categories) _byAmount ? '금액순' : '날짜순',
    if (_imported != null) _imported! ? '자동 기록' : '직접 입력',
  ].join(' · ');

  Future<void> _selectFilters() async {
    final selected = await showAppSheet<LedgerFilters>(
      context: context,
      builder: (_) => LedgerFiltersSheet(
        trip: trip,
        filters: (
          payment: _payment,
          categories: _categories,
          byAmount: _byAmount,
          imported: _imported,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _payment = selected.payment;
      _categories = selected.categories;
      _byAmount = selected.byAmount;
      _imported = selected.imported;
    });
  }

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
      final available =
          RateApi.quotedKrw(trip.country.currency) > 0 &&
          trip.ratesAvailable(trip.expenses);
      final entries = trip.expensesNewestFirst
          .where(
            (e) =>
                (_payment == null ||
                    (e.paymentMethod?.name ?? 'unknown') == _payment) &&
                (!_categories ||
                    _imported == null ||
                    e.isImported == _imported),
          )
          .toList();
      if (_categories && _byAmount) {
        entries.sort((a, b) {
          final amount = b.krwOf(trip).compareTo(a.krwOf(trip));
          return amount == 0 ? b.date.compareTo(a.date) : amount;
        });
      }
      final groups = <Object, List<Expense>>{};
      for (final e in entries) {
        final Object key = _categories
            ? (e.category == '숙소' ? '숙박' : e.category)
            : DateTime(e.date.year, e.date.month, e.date.day);
        (groups[key] ??= []).add(e);
      }
      final orderedGroups = groups.entries.toList();
      if (_categories && _byAmount) {
        orderedGroups.sort(
          (a, b) =>
              trip.spentKrwOf(b.value).compareTo(trip.spentKrwOf(a.value)),
        );
      }
      final now = DateTime.now();
      final today = trip.expenses.where(
        (e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day,
      );
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
                            fontWeight: FontWeight.w500,
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
                              _Figure(
                                label: '오늘 지출',
                                value: available
                                    ? formatWon(trip.spentKrwOf(today))
                                    : '환율 없음',
                              ),
                              _Figure(
                                label: '여행 일정',
                                value: trip.dayLabel(now),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          for (final method in [
                            ...PaymentMethod.values,
                            if (trip.expenses.any(
                              (e) => e.paymentMethod == null,
                            ))
                              null,
                          ])
                            Text(
                              '${method?.label ?? '미지정'} '
                              '${available ? formatWon(trip.spentKrwOf(trip.expenses.where((e) => e.paymentMethod == method))) : '환율 없음'}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: const ValueKey('ledger-filter-menu'),
                        leading: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          _filterLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.expand_more_rounded),
                        onTap: _selectFilters,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 44,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              trip.expenses.isEmpty
                                  ? '아직 기록한 지출이 없어요'
                                  : _imported != null
                                  ? '선택한 조건에 맞는 지출이 없어요'
                                  : '이 결제수단으로 기록한 지출이 없어요',
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '아래에서 지출을 기록할 수 있어요',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final group in orderedGroups) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _categories
                                  ? '${expenseCategoryIcons[group.key] ?? '💸'} ${group.key} · ${group.value.length}건'
                                  : formatShortDateWithWeekday(
                                      group.key as DateTime,
                                    ),
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
                      Material(
                        key: ValueKey('ledger-expense-group-${group.key}'),
                        color: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                showDate: _categories,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ExpenseDetailScreen(
                                      trip: trip,
                                      expenseId: group.value[i].id,
                                    ),
                                  ),
                                ),
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
