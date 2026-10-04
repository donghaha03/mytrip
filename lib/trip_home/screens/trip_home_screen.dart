import 'package:flutter/material.dart';
import '../widgets/category_charts.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../../api/api.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/quick_converter.dart';
import '../widgets/recent_expenses_card.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/sheets.dart';
import '../widgets/today_budget_sheet.dart';
import 'ledger_entry.dart';
import 'more_screen.dart';
import 'spending_overview_screen.dart';

/// 여행별 예산·지출 요약과 환산 화면.
/// 전체 장부와 지출 입력은 ledger_entry.dart에서 연결한다.
class TripHomeScreen extends StatelessWidget {
  const TripHomeScreen({super.key, required this.trip});

  final Trip trip;

  Future<void> _edit(BuildContext context) async {
    final result = await showAppSheet<TripEditResult>(
      context: context,
      builder: (_) => TripEditSheet(trip: trip),
    );
    if (result == null || !context.mounted) return;
    switch (result.action) {
      case TripEditAction.save:
        tripStore.update(
          trip.id,
          name: result.name,
          start: result.range!.start,
          end: result.range!.end,
          budgetKrw: result.budgetKrw,
        );
      case TripEditAction.delete:
        if (!await confirmTripDeletion(context, trip) || !context.mounted) {
          return;
        }
        // 지운 여행 화면에 남아 있으면 안 되니 리스트로 먼저 돌아간다
        Navigator.of(context).pop();
        tripStore.remove(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([tripStore, RateApi.changes]),
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripTopBar(
                trip: trip,
                onMore: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const MoreScreen())),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SpendingCard(
                        trip: trip,
                        onEdit: () => _edit(context),
                        onToday: () => showAppSheet<void>(
                          context: context,
                          builder: (_) =>
                              TodayBudgetSheet(trip: trip, now: DateTime.now()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RecentExpensesCard(
                        trip: trip,
                        now: DateTime.now(),
                        onOpenLedger: () => openLedger(context, trip),
                        onOpenOverview: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SpendingOverviewScreen(trip: trip),
                          ),
                        ),
                        onAddExpense: () => openLedger(
                          context,
                          trip,
                          start: LedgerStart.addExpense,
                        ),
                      ),
                      const SizedBox(height: 8),
                      QuickConverter(country: trip.country),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // 스크롤 위치와 무관하게 장부와 지출 입력으로 이동한다.
        bottomNavigationBar: _BottomBar(trip: trip),
      ),
    );
  }
}

/// "D-11" / "여행 중 · 2일차" / "여행 완료"
String tripStatusLabel(Trip t, DateTime now) {
  // 시각을 버리고 날짜만 비교한다 (UTC 로 맞춰서 서머타임 영향도 없앤다)
  DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final today = day(now);
  final start = day(t.start);
  final end = day(t.end);
  if (today.isBefore(start)) return 'D-${start.difference(today).inDays}';
  if (today.isAfter(end)) return '여행 완료';
  return '여행 중 · ${today.difference(start).inDays + 1}일차';
}

/// 오늘이 여행 기간(시작·종료일 포함) 안에 드는 여행. 없으면 null.
///
/// 앱을 켰을 때 여행 중이면 목록 대신 그 여행 화면부터 보여주려고 쓴다.
/// 기간이 겹치는 여행이 여러 개면 먼저 시작한 쪽을 고른다.
Trip? ongoingTrip(Iterable<Trip> trips, DateTime now) {
  DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final today = day(now);
  Trip? found;
  for (final t in trips) {
    if (day(t.start).isAfter(today) || day(t.end).isBefore(today)) continue;
    if (found == null || t.start.isBefore(found.start)) found = t;
  }
  return found;
}

// ---------------------------------------------------------------------------

/// 메인 카드: 사용한 금액이 가장 크게, 그 아래 예산 대비 진행 바와 남은 금액.
class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.trip,
    required this.onEdit,
    required this.onToday,
  });
  final Trip trip;
  final VoidCallback onEdit, onToday;

  @override
  Widget build(BuildContext context) {
    final available = trip.ratesAvailable(trip.expenses);
    final remain = trip.remainKrw;
    final hasRate = RateApi.quotedKrw(trip.country.currency) > 0;
    String foreign(int krw) =>
        trip.country.formatForeign(RateApi.fromKrw(krw, trip.country.currency));
    String md(DateTime date) =>
        '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.progressTrackOnPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          tripStatusLabel(trip, DateTime.now()),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${md(trip.start)}–${md(trip.end)}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: AppColors.onPrimaryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _CardIcon(
                icon: Icons.today_rounded,
                tooltip: '오늘 예산',
                onTap: onToday,
              ),
              const SizedBox(width: 4),
              _CardIcon(
                icon: Icons.edit_outlined,
                tooltip: '여행 편집',
                onTap: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '사용한 금액',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    available ? formatWon(trip.spentKrw) : '환율 없음',
                    style: const TextStyle(
                      fontSize: 36,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              if (available && hasRate) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      foreign(trip.spentKrw),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.onPrimaryMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          BudgetProgressPanel(trip: trip),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  label: '예산',
                  value: formatWon(trip.budgetKrw),
                  sub: hasRate ? foreign(trip.budgetKrw) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Figure(
                  label: remain < 0 ? '예산 초과' : '남은 금액',
                  value: available ? formatWon(remain.abs()) : '환율 없음',
                  sub: available && hasRate ? foreign(remain.abs()) : null,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 요약 카드의 오늘 예산·편집 버튼.
class _CardIcon extends StatelessWidget {
  const _CardIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.white,
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18, color: AppColors.white),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.sub,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final String? sub;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: AppColors.onPrimaryMuted,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: AppColors.white,
            ),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(
            sub!,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              color: AppColors.onPrimaryMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// 하단 버튼 한 줄. 모양은 02 "여행 만들기", 시트의 "선택 완료" 와 같은 계열
/// (높이 54, 모서리 14) 이라 앱 전체 버튼과 톤이 맞는다.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_rounded,
                  label: '지출 기록',
                  filled: false,
                  onTap: () =>
                      openLedger(context, trip, start: LedgerStart.addExpense),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.document_scanner_outlined,
                  label: '영수증 촬영',
                  filled: true,
                  onTap: () =>
                      openLedger(context, trip, start: LedgerStart.receipt),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.receipt_long_rounded,
                  label: '장부 보기',
                  filled: false,
                  onTap: () => openLedger(context, trip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.white : AppColors.textPrimary;
    return Material(
      color: filled ? AppColors.primary : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
