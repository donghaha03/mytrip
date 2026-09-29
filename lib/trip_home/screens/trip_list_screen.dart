import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../widgets/add_trip_cta.dart';
import '../widgets/app_sheet.dart';
import '../widgets/sheets.dart';
import '../widgets/trip_card.dart';
import 'add_trip_screen.dart';
import 'trip_home_screen.dart';

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
        tripStore.update(
          trip.id,
          name: result.name,
          start: result.range!.start,
          end: result.range!.end,
          budgetKrw: result.budgetKrw,
        );
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
            final now = DateTime.now();
            final today = DateTime.utc(now.year, now.month, now.day);
            DateTime day(DateTime date) =>
                DateTime.utc(date.year, date.month, date.day);
            int group(Trip trip) {
              if (day(trip.end).isBefore(today)) return 2;
              if (day(trip.start).isAfter(today)) return 1;
              return 0;
            }

            // 진행 중인 여행을 먼저, 예정은 가까운 순, 완료는 최근 순으로 보여준다.
            final trips = [...tripStore.trips]
              ..sort((a, b) {
                final order = group(a).compareTo(group(b));
                if (order != 0) return order;
                return group(a) == 2
                    ? b.end.compareTo(a.end)
                    : a.start.compareTo(b.start);
              });
            final featured = trips.isNotEmpty && group(trips.first) < 2
                ? trips.first
                : null;
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${trips.length}개${featured == null ? ' · 모든 여행 완료' : ' · '}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (featured != null)
                        Flexible(
                          child: Text(
                            '${featured.name} ${tripStatusLabel(featured, now)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AddTripCta(
                    label: '여행 선택하기',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddTripScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final trip in trips) ...[
                    TripCard(
                      trip: trip,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TripHomeScreen(trip: trip),
                        ),
                      ),
                      onLongPress: () => _openEditSheet(context, trip),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    '여행을 길게 누르면 이름 · 기간 · 예산을 고치거나 삭제할 수 있어요',
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
