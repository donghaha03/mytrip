import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../../api/api.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/quick_converter.dart';
import '../widgets/rate_info_tooltip.dart';
import '../widgets/recent_expenses_card.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/sheets.dart';
import '../widgets/today_budget_sheet.dart';
import 'ledger_entry.dart';
import 'more_screen.dart';

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
              ScreenTopBar(
                title: '${trip.country.flag} ${trip.name}',
                // 지출 합계와 별도로 현재 API 환율을 표시한다.
                titleSuffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                trailing: _CircleIconButton(
                  icon: Icons.menu_rounded,
                  tooltip: '더보기',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MoreScreen(trip: trip)),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                      const SizedBox(height: 16),
                      RecentExpensesCard(
                        trip: trip,
                        now: DateTime.now(),
                        onOpenLedger: () => openLedger(context, trip),
                        onAddExpense: () => openLedger(
                          context,
                          trip,
                          start: LedgerStart.addExpense,
                        ),
                      ),
                      const SizedBox(height: 16),
                      QuickConverter(country: trip.country),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // body 안에 두면 "준비 중" 스낵바가 버튼을 덮는다. bottomNavigationBar 에
        // 두면 Scaffold 가 스낵바를 이 영역 위로 띄워 준다.
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

/// 여행 일수 (4박 5일 -> 5)
int _tripDays(Trip t) => t.end.difference(t.start).inDays + 1;

String _md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------

/// 메인 카드: 사용한 금액이 가장 크게, 그 아래 예산 대비 진행 바와 남은 금액.
class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.trip,
    required this.onEdit,
    required this.onToday,
  });

  final Trip trip;
  final VoidCallback onEdit;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final c = trip.country;
    final available = RateApi.quotedKrw(c.currency) > 0;
    final remain = trip.remainKrw;
    final over = remain < 0;
    final percent = trip.budgetKrw == 0
        ? 0
        : trip.spentKrw * 100 ~/ trip.budgetKrw;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 · 기간 · 편집
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tripStatusLabel(trip, DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_md(trip.start)} – ${_md(trip.end)} · ${trip.durationLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onPrimaryMuted,
                  ),
                ),
              ),
              _CardIcon(
                icon: Icons.today_rounded,
                tooltip: '오늘 예산',
                onTap: onToday,
              ),
              const SizedBox(width: 6),
              _CardIcon(
                icon: Icons.edit_outlined,
                tooltip: '여행 편집',
                onTap: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 사용한 금액
          const Text(
            '사용한 금액',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    available ? formatWon(trip.spentKrw) : '환율 없음',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
                Text(
                  available
                      ? c.formatForeign(
                          RateApi.fromKrw(trip.spentKrw, c.currency),
                        )
                      : c.formatForeign(trip.spentForeign),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimaryFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 예산 대비 진행
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: trip.spentRatio,
                      minHeight: 8,
                      backgroundColor: AppColors.white.withValues(alpha: 0.22),
                      valueColor: AlwaysStoppedAnimation(
                        over ? const Color(0xFFFFB4B4) : AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  available ? '$percent%' : '—',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 예산 / 남은 금액
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Figure(
                    label: '예산',
                    value: formatWon(trip.budgetKrw),
                    sub: '하루 ${formatWon(trip.budgetKrw ~/ _tripDays(trip))}',
                  ),
                ),
                _Figure(
                  label: over ? '초과' : '남은 금액',
                  value: available ? formatWon(remain.abs()) : '환율 없음',
                  sub: !available
                      ? '환율 없음'
                      : c.formatForeign(
                          RateApi.fromKrw(remain.abs(), c.currency),
                        ),
                  alignEnd: true,
                  warn: over,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 파란 카드 위의 작은 원형 아이콘 버튼 (오늘 예산, 편집)
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
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.white),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.sub,
    this.alignEnd = false,
    this.warn = false,
  });

  final String label;
  final String value;
  final String sub;
  final bool alignEnd;
  final bool warn;

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
            fontWeight: FontWeight.w600,
            color: warn ? const Color(0xFFFFCACA) : AppColors.onPrimaryMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: warn ? const Color(0xFFFFCACA) : AppColors.white,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          sub,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.onPrimaryFaint,
          ),
        ),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                  icon: Icons.receipt_long_rounded,
                  label: '장부 보기',
                  filled: true,
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
          height: 54,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
