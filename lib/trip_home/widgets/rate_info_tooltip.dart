import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../models/country.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'quick_converter.dart';

class CurrentRateBadge extends StatelessWidget {
  const CurrentRateBadge({super.key, required this.country});
  final Country country;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        currentRateLabel(country),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
      RateInfoButton(currency: country.currency),
    ],
  );
}

/// 정기 갱신 일정과 실제 마지막 수집 시각을 구분해 안내한다.
class RateInfoButton extends StatefulWidget {
  const RateInfoButton({super.key, required this.currency});

  final String currency;

  @override
  State<RateInfoButton> createState() => _RateInfoButtonState();
}

class _RateInfoButtonState extends State<RateInfoButton> {
  final _iconKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _removeTooltip() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleTooltip() {
    if (_entry != null) {
      _removeTooltip();
      return;
    }

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final box = _iconKey.currentContext!.findRenderObject() as RenderBox;
    // 창 전체가 아니라 Overlay 기준 좌표로 잡는다. 데스크톱 폭에서는 앱이
    // 가운데 폰 폭으로 묶여 있어서, 창 기준으로 잡으면 말풍선이 옆으로 밀린다.
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final areaWidth = overlayBox.size.width;

    const tooltipWidth = 250.0;
    final tailCenterX = anchor.dx + box.size.width / 2;
    // 화면 밖으로 나가지 않도록 좌우 16px 여백 안에서 클램프
    final left = (tailCenterX - tooltipWidth + 40).clamp(
      16.0,
      areaWidth - tooltipWidth - 16.0,
    );
    final top = anchor.dy + box.size.height + 8;

    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 바깥을 누르면 닫힘
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeTooltip,
              child: const ColoredBox(color: Color(0x0F0F1217)),
            ),
          ),
          Positioned(
            left: tailCenterX - 7,
            top: top - 7,
            child: CustomPaint(
              size: const Size(14, 8),
              painter: _TailPainter(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: tooltipWidth,
            child: _TooltipBody(currency: widget.currency),
          ),
        ],
      ),
    );

    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _iconKey,
      onTap: _toggleTooltip,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // 16px 아이콘은 손가락으로 누르기 작아서 터치 영역만 넓힌다
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textTertiary, width: 1.2),
          ),
          alignment: Alignment.center,
          child: const Text(
            'i',
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TooltipBody extends StatelessWidget {
  const _TooltipBody({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: RateApi.changes,
    builder: (context, _) => _buildBody(),
  );

  Widget _buildBody() {
    final fetched = RateApi.lastFetched?.toUtc().add(const Duration(hours: 9));
    final available = RateApi.quotedKrw(currency) > 0;
    final stamp = fetched == null
        ? null
        : '${formatDate(fetched)} '
              '${fetched.hour.toString().padLeft(2, '0')}:'
              '${fetched.minute.toString().padLeft(2, '0')} KST';
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.tooltipBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '환율 정보',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '자동 갱신: 매일 오전 6시(한국 시간)',
              style: TextStyle(fontSize: 12, color: AppColors.white),
            ),
            const SizedBox(height: 4),
            Text(
              available
                  ? '마지막 수집: $stamp'
                  : RateApi.isLoading
                  ? '환율을 불러오는 중이에요'
                  : '환율을 불러오지 못했어요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 4),
            if (RateApi.hasError || RateApi.isStale)
              Text(
                RateApi.hasError
                    ? available
                          ? '연결 실패 · 저장된 환율을 사용하고 있어요'
                          : '네트워크를 확인하고 다시 시도해주세요'
                    : '자동 갱신 대기 · 저장된 환율 사용 중',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.white.withValues(alpha: 0.6),
                ),
              ),
            if (RateApi.updatedAt != null)
              Text(
                '환율 기준일: ${formatDate(RateApi.updatedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.white.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.tooltipBg;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
