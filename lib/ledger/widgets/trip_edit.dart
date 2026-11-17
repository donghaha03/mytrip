import 'package:flutter/material.dart';

import '../../api/api.dart' show AuthApi;
import '../data/trip_store.dart';
import '../models/trip.dart';
import '../theme/app_colors.dart';
import 'app_sheet.dart';
import 'sheets.dart';

Future<void> editTrip(BuildContext context, Trip trip, TripStore store) async {
  final result = await showAppSheet<TripEditResult>(
    context: context,
    builder: (_) => TripEditSheet(trip: trip),
  );
  if (result == null || !context.mounted) return;
  try {
    switch (result.action) {
      case TripEditAction.save:
        await store.update(
          name: result.name!,
          start: result.range!.start,
          end: result.range!.end,
          budgetKrw: result.budgetKrw!,
        );
      case TripEditAction.delete:
        if (!await confirmTripDeletion(context, trip) || !context.mounted) {
          return;
        }
        await store.remove();
        if (context.mounted) Navigator.of(context).maybePop();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
    }
  }
}

class BudgetCardIcon extends StatelessWidget {
  const BudgetCardIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.white,
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18, color: AppColors.white),
    );
  }
}
