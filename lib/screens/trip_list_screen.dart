import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../widgets/add_trip_cta.dart';
import '../widgets/app_sheet.dart';
import '../widgets/sheets.dart';
import '../widgets/trip_card.dart';
import 'add_trip_screen.dart';
import 'trip_main_screen.dart';

/// 01. 등록된 여행 목록.
class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  Future<void> _openEditSheet(BuildContext context, Trip trip) async {
    final result = await showAppSheet<TripEditResult>(
      context: context,
      builder: (_) => TripEditSheet(trip: trip),
    );
    if (result == null) return;

    switch (result.action) {
      case TripEditAction.save:
        tripStore.rename(trip.id, result.name!);
      case TripEditAction.delete:
        tripStore.remove(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: tripStore,
          builder: (context, _) {
            final trips = tripStore.trips;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '내 여행',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AddTripCta(
                    label: '여행 선택하기',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AddTripScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final trip in trips) ...[
                    TripCard(
                      trip: trip,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TripMainScreen(trip: trip),
                        ),
                      ),
                      onLongPress: () => _openEditSheet(context, trip),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    '여행을 길게 누르면 이름 편집 · 삭제할 수 있어요',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
