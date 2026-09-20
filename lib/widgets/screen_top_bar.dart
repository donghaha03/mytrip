import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 화면 상단의 "← 제목" 바.
///
/// 02/08/09 가 같은 모양을 써야 해서 여기 하나로 모았다.
/// 각자 화면에서 Row 를 새로 짜면 padding·아이콘 크기가 조금씩 달라진다.
class ScreenTopBar extends StatelessWidget {
  const ScreenTopBar({super.key, required this.title, this.trailing});

  final String title;

  /// 오른쪽 끝에 붙일 버튼 (없으면 생략)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            InkResponse(
              onTap: () => Navigator.of(context).pop(),
              radius: 22,
              child: const Icon(Icons.arrow_back_rounded,
                  size: 24, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 아직 구현 전인 화면에 깔아 두는 안내 박스.
/// 담당자가 이 자리를 지우고 내용을 채우면 된다.
class NotBuiltYet extends StatelessWidget {
  const NotBuiltYet({super.key, required this.owner, required this.hint});

  /// 이 화면을 맡은 사람 (README 의 담당 표와 맞춘다)
  final String owner;

  /// 무엇을 만들어야 하는지 한 줄 설명
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🚧  $owner 담당',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
