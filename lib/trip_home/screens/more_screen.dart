import 'package:flutter/material.dart';

import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';
import 'card_connection_screen.dart';

/// 카드 연결과 계정·설정 메뉴.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTopBar(title: '더보기'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: tripStore,
                        builder: (context, _) => ListTile(
                          leading: const Icon(
                            Icons.credit_card_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('카드 연동'),
                          subtitle: Text(
                            tripStore.testCardFor(trip.id)?.displayLabel ??
                                '카드 등록 및 연결 상태',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CardConnectionScreen(trip: trip),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '계정 및 설정 메뉴는 준비 중이에요.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${trip.name} · ${trip.dateRangeLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
