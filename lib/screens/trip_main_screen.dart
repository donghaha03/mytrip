import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../widgets/budget_card.dart';
import '../widgets/rate_info_tooltip.dart';
import 'ledger_screen.dart';
import 'more_screen.dart';

/// 03. 여행 하나를 선택했을 때의 메인 페이지.
class TripMainScreen extends StatelessWidget {
  const TripMainScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: tripStore,
          builder: (context, _) {
            final recent = trip.expensesNewestFirst.take(3).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(trip: trip),
                  const SizedBox(height: 20),
                  BudgetCard(trip: trip),
                  const SizedBox(height: 20),
                  _LedgerButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LedgerScreen(trip: trip),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '최근 지출',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '아직 기록한 지출이 없어요',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final e in recent) ...[
                      ExpenseTile(expense: e, trip: trip),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 뒤로가기 + 여행 이름 + 환율 + i 아이콘 / 우측 햄버거 메뉴
class _TopBar extends StatelessWidget {
  const _TopBar({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 01 여행 리스트에서 밀고 들어온 화면이라 돌아갈 곳이 있을 때만 띄운다.
        if (Navigator.of(context).canPop()) ...[
          InkResponse(
            onTap: () => Navigator.of(context).pop(),
            radius: 22,
            child: const Icon(Icons.arrow_back_rounded,
                size: 24, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '${trip.country.flag} ${trip.name}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trip.country.rateLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              RateInfoButton(
                // 실제 구현에서는 환율 API 마지막 호출 시각을 넣는다.
                lastUpdated: DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                  6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _MenuButton(trip: trip),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MoreScreen(trip: trip)),
        ),
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.menu_rounded,
              size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _LedgerButton extends StatelessWidget {
  const _LedgerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '📒  여행 장부 보기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
