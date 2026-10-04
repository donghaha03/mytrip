import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/trip.dart';
import 'rate_info_tooltip.dart';

/// The trip home and ledger keep the name, rate and menu in the same slots.
class TripTopBar extends StatelessWidget {
  const TripTopBar({super.key, required this.trip, required this.onMore});
  final Trip trip;
  final VoidCallback onMore;
  @override
  Widget build(BuildContext context) => ScreenTopBar(
    title: '${trip.country.flag} ${trip.name}',
    titleSuffix: CurrentRateBadge(country: trip.country),
    trailing: IconButton(
      tooltip: '더보기',
      onPressed: onMore,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.menu_rounded, size: 20),
    ),
  );
}

/// 화면 상단의 "← 제목" 바.
///
/// 02/08/09 가 같은 모양을 써야 해서 여기 하나로 모았다.
/// 각자 화면에서 Row 를 새로 짜면 padding·아이콘 크기가 조금씩 달라진다.
class ScreenTopBar extends StatelessWidget {
  const ScreenTopBar({
    super.key,
    required this.title,
    this.titleSuffix,
    this.trailing,
  });

  final String title;

  /// 제목 바로 뒤에 붙는 작은 정보 (예: 여행 홈의 "¥100 = ₩950 ⓘ").
  /// 제목이 길면 제목 쪽이 말줄임되고 이건 그대로 보인다.
  final Widget? titleSuffix;

  /// 오른쪽 끝에 붙일 버튼 (없으면 생략)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            Semantics(
              button: true,
              label: '뒤로가기',
              child: InkResponse(
                onTap: () => Navigator.of(context).pop(),
                radius: 22,
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Row(
              children: [
                Flexible(
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
                if (titleSuffix != null) ...[
                  const SizedBox(width: 8),
                  titleSuffix!,
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
