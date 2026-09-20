import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// i 아이콘을 누르면 바로 아래에 붙어서 뜨는 환율 갱신 안내 말풍선.
/// 무료 환율 API 를 쓰는 구조라 하루 한 번만 갱신된다는 점을 알려준다.
class RateInfoButton extends StatefulWidget {
  const RateInfoButton({super.key, required this.lastUpdated});

  final DateTime lastUpdated;

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

    final box = _iconKey.currentContext!.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    const tooltipWidth = 250.0;
    final tailCenterX = anchor.dx + box.size.width / 2;
    // 화면 밖으로 나가지 않도록 좌우 16px 여백 안에서 클램프
    final left = (tailCenterX - tooltipWidth + 40)
        .clamp(16.0, screenWidth - tooltipWidth - 16.0);
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
            child: _TooltipBody(lastUpdated: widget.lastUpdated),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _iconKey,
      onTap: _toggleTooltip,
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
    );
  }
}

class _TooltipBody extends StatelessWidget {
  const _TooltipBody({required this.lastUpdated});

  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    final t = lastUpdated;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
              '환율 갱신 정보',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '최근 갱신: ${formatDate(t)} $time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '환율은 24시간마다 한 번 갱신돼요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
