import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/onboarding_example.dart';
import '../widgets/screen_top_bar.dart';
import '../theme/app_colors.dart';
import '../widgets/add_trip_cta.dart';
import 'add_trip_screen.dart';
import 'more_screen.dart';

/// The tutorial finishes at the welcome screen, never in a form.
class EmptyHomeScreen extends StatefulWidget {
  const EmptyHomeScreen({
    super.key,
    this.guideOnly = false,
    this.showGuide = true,
    this.onGuideFinished,
  });
  final bool guideOnly;
  final bool showGuide;
  final VoidCallback? onGuideFinished;
  @override
  State<EmptyHomeScreen> createState() => _EmptyHomeScreenState();
}

class _EmptyHomeScreenState extends State<EmptyHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _slides = [
    (title: '여행을 추가해요', description: '국가와 일정, 예산을 정하면 준비 끝.'),
    (title: '지출을 기록해요', description: '사용처와 금액, 현금·카드와 면세 여부를 기록해요.'),
    (
      title: '왼쪽으로 밀어 관리해요',
      description: '왼쪽으로 밀면 수정·삭제, 오른쪽으로 밀면 이전 화면으로 돌아가요.',
    ),
    (title: '영수증으로 간편하게', description: '촬영하거나 사진을 골라, 확인 후 기록해요.'),
    (title: '지출을 한눈에 봐요', description: '카테고리별 구성비를 보고, 빠른 환산으로 현지 금액을 확인해요.'),
  ];
  final _pages = PageController();
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late bool _showGuide = widget.guideOnly || widget.showGuide;
  bool _departing = false;
  int _page = 0;
  @override
  void dispose() {
    _pages.dispose();
    _flight.dispose();
    super.dispose();
  }

  void _move(int offset) {
    if (_departing) return;
    final target = (_page + offset).clamp(0, _slides.length);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish() {
    widget.onGuideFinished?.call();
    if (widget.guideOnly && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _showGuide = false;
        _departing = false;
      });
    }
  }

  Future<void> _depart() async {
    if (_departing || !mounted) return;
    setState(() => _departing = true);
    _flight.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 2200);
    try {
      await _flight.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showGuide) return _welcome();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                ScreenTopBar(
                  title: '앱 사용방법',
                  trailing: TextButton(
                    onPressed: _departing ? null : _finish,
                    child: const Text('건너뛰기'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    key: const ValueKey('welcome-pages'),
                    controller: _pages,
                    itemCount: _slides.length + 1,
                    onPageChanged: (i) {
                      if (i == _slides.length) {
                        _depart();
                      } else {
                        setState(() => _page = i);
                      }
                    },
                    itemBuilder: (context, i) => i == _slides.length
                        ? const SizedBox.expand()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _slides[i].title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _slides[i].description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                OnboardingExample(step: i),
                              ],
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      _FlightProgress(progress: _page / (_slides.length - 1)),
                      Row(
                        children: [
                          IconButton(
                            tooltip: '이전 안내',
                            onPressed: _page == 0 || _departing
                                ? null
                                : () => _move(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              '${_page + 1} / ${_slides.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _page == _slides.length - 1
                                ? '출발하기'
                                : '다음 안내',
                            onPressed: _departing ? null : () => _move(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const Text(
                        '왼쪽으로 넘겨보세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_departing)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.primarySoft,
                  child: AnimatedBuilder(
                    animation: _flight,
                    builder: (context, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 180,
                              child: LayoutBuilder(
                                builder: (_, constraints) {
                                  final size = Size(constraints.maxWidth, 180);
                                  final path = _flightPath(
                                    size,
                                  ).computeMetrics().single;
                                  final progress = const Interval(
                                    .25,
                                    .75,
                                    curve: Curves.easeInOutCubic,
                                  ).transform(_flight.value);
                                  final point = path.getTangentForOffset(
                                    path.length * progress,
                                  )!;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Positioned(
                                        left: 24,
                                        top: 16,
                                        child: Icon(
                                          Icons.cloud_outlined,
                                          size: 44,
                                          color: AppColors.white,
                                        ),
                                      ),
                                      const Positioned(
                                        right: 28,
                                        bottom: 28,
                                        child: Icon(
                                          Icons.cloud_outlined,
                                          size: 36,
                                          color: AppColors.white,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _FlightPathPainter(),
                                        ),
                                      ),
                                      Positioned(
                                        left: point.position.dx - 22,
                                        top: point.position.dy - 22,
                                        child: Transform.rotate(
                                          angle: point.angle + math.pi / 2,
                                          child: const Icon(
                                            Icons.flight_rounded,
                                            size: 44,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '여행을 준비하러 출발해요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFF4FE), Color(0xFFF9FAFC), AppColors.bg],
          stops: [0, .55, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _BrandBadge(),
                    ),
                  ),
                  IconButton(
                    tooltip: '더보기',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MoreScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlaneMark(icon: Icons.flight_takeoff_rounded),
                      SizedBox(height: 28),
                      Text(
                        '첫 여행을 추가해 보세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '여행 일정과 지출을 한곳에서 관리해요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 24),
                      _FeatureRow(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  AddTripCta(
                    label: '여행 추가하기',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddTripScreen(),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _showGuide = true;
                      _page = 0;
                    }),
                    child: const Text('사용방법 다시 보기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
          Icon(
            Icons.flight_takeoff_rounded,
            size: 13,
            color: AppColors.primary,
          ),
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
  const _PlaneMark({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _FlightPathPainter())),
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
            child: Icon(icon, size: 44, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _FlightProgress extends StatelessWidget {
  const _FlightProgress({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '여행 준비 ${(progress * 100).round()}퍼센트',
    child: SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Divider(color: AppColors.progressTrack),
          AnimatedAlign(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment(-1 + 2 * progress, 0),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              size: 24,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

Path _flightPath(Size size) => Path()
  ..moveTo(size.width * 0.02, size.height * 0.86)
  ..quadraticBezierTo(
    size.width * 0.35,
    size.height * 0.05,
    size.width * 0.98,
    size.height * 0.16,
  );

class _FlightPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = _flightPath(size);

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
        const Expanded(
          child: _Feature(icon: '💱', label: '자동 환산'),
        ),
        _divider(),
        const Expanded(
          child: _Feature(icon: '📍', label: '소비 기록'),
        ),
        _divider(),
        const Expanded(
          child: _Feature(icon: '📊', label: '예산 관리'),
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 22, color: AppColors.divider);
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
