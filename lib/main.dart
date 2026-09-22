import 'package:flutter/material.dart';

import 'data/trip_store.dart';
import 'screens/empty_home_screen.dart';
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
    // 로그인 화면은 이 저장소 범위 밖이다 (로그인 담당). 로그인 기능 자체
    // (authService)와 "로그인하면 그 사람의 Firestore 에 붙는" 연결은 미리 해
    // 뒀으니, 로그인 화면에서 authService.signIn 을 부르기만 하면 된다.
    // 로그인 전에는 데이터가 메모리에만 있다.
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
      // 시트·스낵바 오버레이도 builder 안쪽이라 같이 묶인다.
      builder: (context, child) => ColoredBox(
        color: AppColors.frame,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kPhoneWidth),
            child: child,
          ),
        ),
      ),
      home: const HomeRouter(),
    );
  }
}

/// 이 폭을 넘어가면 더 늘리지 않는다. 일반적인 폰 가로폭(≤430) 기준.
const kPhoneWidth = 440.0;

/// 여행이 없으면 00 첫 화면, 있으면 01 여행 리스트.
///
/// 로그인 담당: 로그인 화면을 앞에 세우려면 여기(또는 TripApp.home)를
/// "authService.isSignedIn 이면 HomeRouter, 아니면 로그인 화면" 으로 감싸면 된다.
/// authService 는 ChangeNotifier 라 AnimatedBuilder 로 감싸면 로그인 즉시 넘어간다.
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
