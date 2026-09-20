import 'package:flutter/material.dart';

import 'data/trip_store.dart';
import 'screens/empty_home_screen.dart';
import 'screens/trip_list_screen.dart';
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
      home: const HomeRouter(),
    );
  }
}

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
