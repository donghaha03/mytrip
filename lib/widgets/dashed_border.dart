import 'package:flutter/material.dart';

/// 둥근 사각형 점선 테두리. Flutter 기본 Border 로는 점선을 못 그려서 직접 그린다.
class DashedRoundedBorder extends StatelessWidget {
  const DashedRoundedBorder({
    super.key,
    required this.child,
    required this.radius,
    required this.color,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 4,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        radius: radius,
        color: color,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
