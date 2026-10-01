import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dashed_border.dart';

/// 점선 테두리 + 파란 원형 플러스가 붙은 여행 추가 버튼.
/// 00 첫 화면과 01 여행 리스트에서 같은 컴포넌트를 쓴다.
class AddTripCta extends StatelessWidget {
  const AddTripCta({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashedRoundedBorder(
      radius: 18,
      color: AppColors.primary.withValues(alpha: 0.35),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '+',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
