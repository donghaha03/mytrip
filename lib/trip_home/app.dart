import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart' show AuthApi;
import '../auth_gate.dart';
import '../ledger/theme/app_colors.dart';
import '../ledger/theme/app_theme.dart';
import 'data/trip_list_store.dart';
import 'screens/empty_home_screen.dart';
import 'screens/trip_home_screen.dart';
import 'screens/trip_list_screen.dart';

class TripApp extends StatefulWidget {
  const TripApp({super.key, this.home});

  /// 테스트에서 로그인 분기 없이 화면을 띄울 때만 넘긴다.
  final Widget? home;

  @override
  State<TripApp> createState() => _TripAppState();
}

class _TripAppState extends State<TripApp> {
  final _navigator = GlobalKey<NavigatorState>();
  double _backSwipe = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: '여행 장부',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 폰 기준으로 짠 레이아웃이라 데스크톱/태블릿 폭에서 그냥 늘리면
      // 그리드 칸이 거대한 정사각형으로 벌어진다. 폰 폭으로 묶어서 가운데 세운다.
      // 시트·스낵바 오버레이도 builder 안쪽이라 같이 묶인다.
      builder: (context, child) => ColoredBox(
        color: AppColors.frame,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: !kIsWeb && MediaQuery.sizeOf(context).shortestSide < 600
                  ? double.infinity
                  : kPhoneWidth,
            ),
            child: GestureDetector(
              key: const ValueKey('app-swipe-back'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _backSwipe = 0,
              onHorizontalDragUpdate: (details) =>
                  _backSwipe += details.delta.dx,
              onHorizontalDragCancel: () => _backSwipe = 0,
              onHorizontalDragEnd: (_) {
                if (_backSwipe >= 96) _navigator.currentState?.maybePop();
                _backSwipe = 0;
              },
              child: child,
            ),
          ),
        ),
      ),
      // 로그인 전에는 로그인 화면, 로그인하면 그 사용자의 여행 목록.
      home: widget.home ?? const AuthGate(home: HomeRouter()),
    );
  }
}

/// 이 폭을 넘어가면 더 늘리지 않는다. 일반적인 폰 가로폭(≤430) 기준.
const kPhoneWidth = 440.0;

/// 여행이 없으면 00 첫 화면, 있으면 01 여행 리스트.
///
/// **오늘이 어떤 여행 기간 안이면** 목록 대신 그 여행 화면부터 띄운다.
/// 목록 위에 "쌓아서" 띄우기 때문에 좌측 상단 뒤로가기를 누르면 목록으로 간다.
/// 앱을 켠 뒤 한 번만 자동으로 열고, 목록으로 나온 뒤에는 다시 열지 않는다.
///
/// AuthGate 아래(로그인 상태)에서만 만든다. 여행 목록은 팀 API에서 읽는다.
class HomeRouter extends StatefulWidget {
  const HomeRouter({super.key, this.store});

  /// 테스트에서 가짜 목록을 끼울 때만 넘긴다. 넘긴 쪽이 dispose 한다.
  final TripListStore? store;

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  late final TripListStore _store = widget.store ?? TripListStore();
  bool _autoOpened = false;
  bool? _guideSeen;

  @override
  void initState() {
    super.initState();
    _loadGuidePreference();
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  Future<void> _loadGuidePreference() async {
    var seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool('trip_guide_seen') ?? false;
    } catch (_) {
      // Without storage, show guidance rather than bypassing it.
    }
    if (mounted) {
      setState(() {
        _guideSeen = seen;
      });
    }
  }

  void _completeGuide() {
    setState(() => _guideSeen = true);
    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setBool('trip_guide_seen', true))
          .catchError((_) => false),
    );
  }

  /// 여행 중인 여행이 있으면 그 화면을 목록 위에 띄운다.
  /// 첫 목록이 올 때까지 기다린다.
  void _openOngoingTripOnce() {
    if (_autoOpened || _store.isLoading) return;
    final trip = ongoingTrip(_store.trips, DateTime.now());
    if (trip == null) return;
    final tripStore = _store.stores.firstWhere((s) => s.tripId == trip.id);

    _autoOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          // 앱을 켜자마자 뜨는 화면이라 넘어가는 애니메이션은 없앤다
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => TripHomeScreen(store: tripStore),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) => AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: _screen(),
      ),
    );
  }

  Widget _screen() {
    if (_guideSeen == null) return const _Loading();
    if (!_guideSeen!) {
      return EmptyHomeScreen(
        key: const ValueKey('first-run-guide'),
        onGuideFinished: _completeGuide,
      );
    }
    if (_store.error != null) {
      return Scaffold(
        key: const ValueKey('trip-list-error'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AuthApi.errorMessage(_store.error!),
                textAlign: TextAlign.center,
              ),
              TextButton(onPressed: _store.retry, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    if (_store.isLoading) return const _Loading();
    _openOngoingTripOnce();
    return _store.isEmpty
        ? const EmptyHomeScreen(
            key: ValueKey('empty-welcome'),
            showGuide: false,
          )
        : TripListScreen(store: _store);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
