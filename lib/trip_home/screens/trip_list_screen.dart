import 'package:flutter/material.dart';

import '../../ledger/data/rates.dart';
import '../../api/api.dart' show AuthApi;
import '../../ledger/data/trip_store.dart';
import '../../ledger/widgets/trip_edit.dart';
import '../data/trip_list_store.dart';
import '../../ledger/models/trip.dart';
import '../../ledger/theme/app_colors.dart';
import '../widgets/add_trip_cta.dart';
import '../../ledger/widgets/sheets.dart';
import '../widgets/trip_card.dart';
import 'add_trip_screen.dart';
import 'trip_home_screen.dart';
import 'more_screen.dart';
import 'empty_home_screen.dart';

/// 01. 등록된 여행 목록.
class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key, required this.store});
  final TripListStore store;

  Future<void> _delete(BuildContext context, TripStore tripStore) async {
    if (!await confirmTripDeletion(context, tripStore.trip!)) return;
    try {
      await tripStore.remove();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([store, RateApi.changes]),
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
            final byTrip = {for (final s in store.stores) s.trip!: s};
            final trips = [...byTrip.keys]
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '내 여행',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '앱 사용방법',
                        icon: const Icon(Icons.help_outline_rounded),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const EmptyHomeScreen(guideOnly: true),
                          ),
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
                    label: '여행 추가하기',
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
                          builder: (_) => TripHomeScreen(store: byTrip[trip]!),
                        ),
                      ),
                      onLongPress: () => editTrip(context, trip, byTrip[trip]!),
                      onDelete: () => _delete(context, byTrip[trip]!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    '여행을 왼쪽으로 밀어 수정·삭제할 수 있어요',
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
