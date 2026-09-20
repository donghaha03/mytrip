import 'package:flutter/material.dart';

import 'data/trip_store.dart';
import 'screens/empty_home_screen.dart';
import 'screens/trip_list_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  // 목업 여행 3건을 채운 상태로 시작한다.
  // 00 빈 화면을 보려면 이 줄을 주석 처리하면 된다.
  tripStore.seedMockTrips();

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
      home: const HomeRouter(),
    );
  }
}

/// 이 폭을 넘어가면 더 늘리지 않는다. 일반적인 폰 가로폭(≤430) 기준.
const kPhoneWidth = 440.0;

/// 여행이 없으면 00 첫 화면, 있으면 01 여행 리스트.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tripStore,
      builder: (context, _) => tripStore.isEmpty
          ? const EmptyHomeScreen()
          : const TripListScreen(),
    );
  }
}
