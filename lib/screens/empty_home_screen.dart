import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/add_trip_cta.dart';
import 'add_trip_screen.dart';

/// 00. 여행이 하나도 없을 때 보이는 첫 화면.
class EmptyHomeScreen extends StatelessWidget {
  const EmptyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEFF4FE),
              Color(0xFFF9FAFC),
              AppColors.bg,
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BrandBadge(),
                  const SizedBox(height: 26),
                  const _PlaneMark(),
                  const SizedBox(height: 28),
                  const Text(
                    '아직 떠날 준비가 남았어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '첫 여행을 추가하면\n쓴 만큼 바로 원화로 보여드릴게요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  AddTripCta(
                    label: '여행 추가하기',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AddTripScreen()),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _FeatureRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.flight_takeoff_rounded,
              size: 13, color: AppColors.primary),
          SizedBox(width: 6),
          Text(
            '환율 걱정 없는 여행 장부',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 점선 비행 경로 위에 떠 있는 원형 마크.
class _PlaneMark extends StatelessWidget {
  const _PlaneMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _FlightPathPainter()),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  offset: const Offset(0, 10),
                  blurRadius: 24,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.send_rounded,
                size: 44, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _FlightPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.98,
        size.height * 0.16,
      );

    // 점선으로 끊어 그리기
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 7;
      }
    }

    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.86),
      4,
      Paint()..color = AppColors.primary.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Expanded(child: _Feature(icon: '💱', label: '자동 환산')),
        _divider(),
        const Expanded(child: _Feature(icon: '📍', label: '소비 기록')),
        _divider(),
        const Expanded(child: _Feature(icon: '📊', label: '예산 관리')),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 22,
        color: AppColors.divider,
      );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
