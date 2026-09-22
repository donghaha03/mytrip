import 'package:flutter/material.dart';

import 'data/trip_store.dart';
import 'screens/empty_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/trip_list_screen.dart';
import 'services/auth_service.dart';
import 'services/backend.dart';
import 'services/session.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // firebase_options.dart 가 채워져 있으면 Firebase, 아니면 로컬 임시 모드.
  if (await Backend.init() == BackendMode.firebase) {
    authService = FirebaseAuthService();
    bindTripStoreToAuth(authService, tripStore);
  } else {
    // 로컬에서는 목업 여행 3건으로 시작한다.
    // 00 빈 화면을 보려면 이 줄을 주석 처리하면 된다.
    tripStore.seedMockTrips();
  }

  runApp(const TripApp());
}

class TripApp extends StatelessWidget {
  const TripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '여행 장부',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 폰 기준으로 짠 레이아웃이라 데스크톱/태블릿 폭에서 그냥 늘리면
      // 그리드 칸이 거대한 정사각형으로 벌어진다. 폰 폭으로 묶어서 가운데 세운다.
      // 시트·스낵바·툴팁 오버레이도 builder 안쪽이라 같이 묶인다.
      builder: (context, child) => ColoredBox(
        color: AppColors.frame,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kPhoneWidth),
            child: child,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// 이 폭을 넘어가면 더 늘리지 않는다. 일반적인 폰 가로폭(≤430) 기준.
const kPhoneWidth = 440.0;

/// 로그인 안 했으면 로그인 화면, 했으면 여행 화면.
///
/// 로그인 화면에서 성공한 뒤 직접 화면을 넘길 필요 없다 — authService 가
/// 바뀌면 여기서 알아서 바꾼다. 로그아웃하면 쌓여 있던 화면(03, 더보기 등)을
/// 전부 걷어내고 로그인으로 돌아온다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _wasSignedIn = authService.isSignedIn;

  @override
  void initState() {
    super.initState();
    authService.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final signedIn = authService.isSignedIn;
    if (_wasSignedIn && !signedIn) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    _wasSignedIn = signedIn;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!authService.isReady) return const _Loading();
    return authService.isSignedIn ? const HomeRouter() : const LoginScreen();
  }
}

/// 여행이 없으면 00 첫 화면, 있으면 01 여행 리스트.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tripStore,
      builder: (context, _) {
        if (tripStore.isLoading) return const _Loading();
        return tripStore.isEmpty
            ? const EmptyHomeScreen()
            : const TripListScreen();
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
