import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 03 메인 화면 상단의 파란 예산 요약 카드.
/// 남은 예산을 원화(큰 글씨) + 현지 통화(회색 반투명)로 같이 보여준다.
class BudgetCard extends StatelessWidget {
  const BudgetCard({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final yesterday = trip.yesterdaySpentKrw;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20).copyWith(top: 24, bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '남은 예산',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            formatWon(trip.remainKrw),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            trip.country.formatForeign(trip.remainForeign),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onPrimaryFaint,
            ),
          ),
          if (yesterday > 0) ...[
            const SizedBox(height: 16),
            _ChangeBadge(amountKrw: yesterday),
          ],
          const SizedBox(height: 16),
          _ProgressBar(ratio: trip.spentRatio),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Figure(
                label: '총 지출',
                krw: trip.spentKrw,
                foreign: trip.country.formatForeign(trip.spentForeign),
              ),
              _Figure(
                label: '총 예산',
                krw: trip.budgetKrw.toDouble(),
                foreign: trip.country.formatForeign(trip.budgetForeign),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.amountKrw});

  final double amountKrw;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_drop_down_rounded,
              size: 18, color: Color(0xFFFFBFBF)),
          const SizedBox(width: 2),
          Text(
            '어제보다 ${formatWon(amountKrw)} 감소',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onPrimaryMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 8,
        backgroundColor: AppColors.progressTrack,
        valueColor: const AlwaysStoppedAnimation(AppColors.white),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.krw,
    required this.foreign,
  });

  final String label;
  final double krw;
  final String foreign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.onPrimaryMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatWon(krw),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          foreign,
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

/// 최근 지출 목록 한 줄.
/// 왼쪽: 아이콘 / 사용처 / 현지 통화 금액, 오른쪽: 원화 환산 금액.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.trip,
  });

  final Expense expense;
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(expense.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.place,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trip.country.formatForeign(expense.amount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            formatWon(trip.country.toKrw(expense.amount)),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
