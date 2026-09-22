import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/screen_top_bar.dart';
import '../widgets/sheets.dart';
import 'ledger_entry.dart';
import 'more_screen.dart';

/// 여행 홈. 01 리스트에서 여행을 누르면 들어온다.
///
/// 여행 계획(언제·얼마나·예산)만 보여준다. 돈을 쓴 이야기 — 남은 예산,
/// 지출 목록, 환율 툴팁(Figma 03/07) — 는 장부 페이지 몫이라 여기 두지 않고,
/// 하단 버튼으로 장부에 넘긴다. 장부 연결은 ledger_entry.dart 에서 한다.
///
///   ← 🇯🇵 일본 여행                    ≡     ≡ = 더보기 (Figma 03 과 같은 자리)
///   ┌ 파란 카드: D-day · 기간 ──── ✎ ┐     ✎ = 06 여행 편집
///   └───────────────────────────────┘
///   ┌ 흰 카드: 예산 · 하루 예산 ──────┐
///   └───────────────────────────────┘
///   [ + 지출 기록 ]  [ 장부 보기 ]           -> 장부
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
        tripStore.rename(trip.id, result.name!);
      case TripEditAction.delete:
        // 지운 여행 화면에 남아 있으면 안 되니 리스트로 먼저 돌아간다
        Navigator.of(context).pop();
        tripStore.remove(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tripStore,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenTopBar(
                title: '${trip.country.flag} ${trip.name}',
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
                      _HeroCard(trip: trip, onEdit: () => _edit(context)),
                      const SizedBox(height: 16),
                      _BudgetCard(trip: trip),
                      const SizedBox(height: 14),
                      const Text(
                        '남은 예산과 지출 내역은 장부에서 볼 수 있어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
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

/// 여행 일수 (4박 5일 -> 5)
int _tripDays(Trip t) => t.end.difference(t.start).inDays + 1;

// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.trip, required this.onEdit});

  final Trip trip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tripStatusLabel(trip, DateTime.now()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: '여행 편집',
                child: InkResponse(
                  onTap: onEdit,
                  radius: 22,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined,
                        size: 17, color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            trip.durationLabel,
            style: const TextStyle(
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            trip.dateRangeLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onPrimaryMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 예산 + 하루 예산. 둘 다 "계획" 숫자라 여기 둔다 (쓴 돈은 장부).
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final days = _tripDays(trip);
    final c = trip.country;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '예산',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatWon(trip.budgetKrw),
            style: const TextStyle(
              fontSize: 26,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '≈ ${c.formatForeign(trip.budgetForeign)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '하루 예산 · $days일',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatWon(trip.budgetKrw / days),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '≈ ${c.formatForeign(trip.budgetForeign / days)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
                  onTap: () => openLedger(context, trip,
                      start: LedgerStart.addExpense),
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
