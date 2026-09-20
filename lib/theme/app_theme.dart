import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    ),
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}

/// 1234567 -> "1,234,567"
String formatNumber(num value) {
  final isNegative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${isNegative ? '-' : ''}$buffer';
}

/// 742300 -> "742,300원"
String formatWon(num value) => '${formatNumber(value)}원';

/// 2026-10-01 -> "2026.10.01"
String formatDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 2026-10-01 -> "10.01 (목)"
String formatShortDateWithWeekday(DateTime d) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final w = weekdays[d.weekday - 1];
  return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ($w)';
}
