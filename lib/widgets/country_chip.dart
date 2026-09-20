import 'package:flutter/material.dart';

import '../models/country.dart';
import '../theme/app_colors.dart';
import 'dashed_border.dart';

/// 국기 + 통화코드가 세로로 쌓인 선택 칩.
class CountryChip extends StatelessWidget {
  const CountryChip({
    super.key,
    required this.country,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final Country country;
  final bool selected;
  final VoidCallback onTap;

  /// 04 더보기 시트에서는 한 줄에 4개가 더 빡빡하게 들어간다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
              vertical: 10, horizontal: compact ? 4 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // height 를 고정하지 않으면 이모지 폰트 메트릭 때문에
              // 그리드 칸(childAspectRatio 1.15)을 살짝 넘겨서 overflow 가 난다.
              Text(country.flag,
                  style: TextStyle(
                    fontSize: compact ? 18 : 20,
                    height: 1.1,
                  )),
              const SizedBox(height: 2),
              Text(
                country.currency,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 02 화면 국가 그리드 마지막 칸의 점선 "더보기" 칩.
class MoreCountryChip extends StatelessWidget {
  const MoreCountryChip({
    super.key,
    required this.onTap,
    this.selectedCountry,
  });

  /// 더보기에서 국가를 고른 상태면 그 국기를 보여준다.
  final Country? selectedCountry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = selectedCountry;
    return DashedRoundedBorder(
      radius: 12,
      color: picked != null ? AppColors.primary : AppColors.border,
      strokeWidth: picked != null ? 2 : 1,
      dash: 3,
      gap: 3,
      child: Material(
        color: picked != null ? AppColors.primarySoft : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  picked?.flag ?? '···',
                  style: TextStyle(
                    fontSize: picked != null ? 20 : 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  picked?.currency ?? '더보기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: picked != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
