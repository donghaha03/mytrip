import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/app_colors.dart';

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onLongPress,
  });

  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(trip.country.flag,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          trip.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trip.dateRangeLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (trip.isCompleted)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: CompletedStamp(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 종료일이 지난 여행에 찍히는 "여행완료" 도장.
class CompletedStamp extends StatelessWidget {
  const CompletedStamp({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -12 * math.pi / 180,
      child: Opacity(
        opacity: 0.85,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.danger, width: 2.5),
          ),
          child: const Text(
            '여행완료',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ),
      ),
    );
  }
}
