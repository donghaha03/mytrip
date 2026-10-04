import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../theme/app_colors.dart';
import '../widgets/add_trip_cta.dart';
import 'add_trip_screen.dart';
import 'more_screen.dart';

/// 00. 여행이 하나도 없을 때 보이는 첫 화면.
class EmptyHomeScreen extends StatefulWidget {
  const EmptyHomeScreen({super.key, this.guideOnly = false});
  final bool guideOnly;
  @override
  State<EmptyHomeScreen> createState() => _EmptyHomeScreenState();
}

class _EmptyHomeScreenState extends State<EmptyHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _slides = [
    (
      title: '첫 여행을 추가해 보세요',
      description: '여행 일정과 지출을 한곳에서 관리해요',
      icon: Icons.send_rounded,
    ),
    (
      title: '일정과 예산부터 정해요',
      description: '국가·여행 기간·원화 예산을 정해요.\n달력의 연·월 제목을 누르면 먼 날짜로 바로 이동할 수 있어요.',
      icon: Icons.calendar_month_rounded,
    ),
    (
      title: '지출을 간편하게 기록해요',
      description: '현금·카드와 면세 여부를 구분해요.\n영수증 촬영으로 자동 입력하고, 내용을 확인·수정한 뒤 저장해요.',
      icon: Icons.receipt_long_rounded,
    ),
    (
      title: '밀어서 수정하고 삭제해요',
      description:
          '여행 카드와 지출을 오른쪽으로 밀면 삭제, 왼쪽으로 밀면 수정 아이콘이 나와요.\n길게 눌러도 편집할 수 있어요. 삭제 전에는 다시 확인해요.',
      icon: Icons.swipe_rounded,
    ),
    (
      title: '지출을 한눈에 확인해요',
      description:
          '지출보기는 전체 목록, 한눈에 보기는 카테고리별 차트예요.\n현재 표시 환율로 정수 환산하고, 환율이 없으면 통화별로 구분해요.',
      icon: Icons.pie_chart_outline_rounded,
    ),
    (
      title: '이제 여행을 떠나볼까요?',
      description: '한 번 더 오른쪽으로 넘겨주세요.\n새 여행의 일정과 예산을 준비하러 출발해요.',
      icon: Icons.flight_takeoff_rounded,
    ),
  ];
  late final _pages = PageController(initialPage: widget.guideOnly ? 1 : 0);
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late int _page = widget.guideOnly ? 1 : 0;
  bool _departing = false;
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

  Future<void> _depart() async {
    if (_departing || !mounted) return;
    setState(() => _departing = true);
    _flight.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650);
    try {
      await _flight.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    final count = tripStore.trips.length;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AddTripScreen()));
    if (!mounted) return;
    if (widget.guideOnly && tripStore.trips.length > count) {
      Navigator.of(context).pop();
      return;
    }
    _pages.jumpToPage(_slides.length - 1);
    _flight.reset();
    setState(() => _departing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF4FE), Color(0xFFF9FAFC), AppColors.bg],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                    child: Row(
                      children: [
                        if (widget.guideOnly)
                          IconButton(
                            tooltip: '안내 닫기',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
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
                  Expanded(
                    child: PageView.builder(
                      key: const ValueKey('welcome-pages'),
                      controller: _pages,
                      reverse: true,
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
                          : Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PlaneMark(icon: _slides[i].icon),
                                    const SizedBox(height: 26),
                                    Text(
                                      i == 0 && widget.guideOnly
                                          ? '여행을 준비해 보세요'
                                          : _slides[i].title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        height: 1.4,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _slides[i].description,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.7,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (i == 0) ...[
                                      const SizedBox(height: 24),
                                      const _FeatureRow(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(
                      children: [
                        _FlightProgress(progress: _page / (_slides.length - 1)),
                        Row(
                          children: [
                            IconButton(
                              tooltip: '이전 안내',
                              onPressed: _page == 0 ? null : () => _move(-1),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(
                              child: Text(
                                '${_page + 1} / ${_slides.length} · 오른쪽으로 넘겨보세요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: _page == _slides.length - 1
                                  ? '출발하기'
                                  : '다음 안내',
                              onPressed: () => _move(1),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                        AddTripCta(label: '여행 추가하기', onTap: _depart),
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
                      builder: (context, _) => LayoutBuilder(
                        builder: (context, size) => Stack(
                          alignment: Alignment.center,
                          children: [
                            const Text(
                              '여행을 준비하러 출발해요',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(
                                _flight.value * size.maxWidth,
                                -80 - _flight.value * size.maxHeight * .4,
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                size: 72,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.primarySoft),
              child: Icon(
                Icons.send_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
