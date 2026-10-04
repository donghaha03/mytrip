import 'package:flutter/material.dart';

/// Figma 파일 "환율 여행 장부앱 - PBL1" 의 색상 토큰.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF7F8FA);
  static const white = Color(0xFFFFFFFF);

  /// 데스크톱 폭에서 폰 화면 바깥에 깔리는 여백 색
  static const frame = Color(0xFFE7EAF0);

  static const primary = Color(0xFF2F6FED);
  static const primarySoft = Color(0xFFEAF0FD); // 칩/배지 배경
  static const primaryLight = Color(0xFFD4E0F9); // 달력 range 배경
  static const progressTrack = Color(0xFFC8D8F9);
  static const progressTrackOnPrimary = Color(0xFF2454B2);

  static const textPrimary = Color(0xFF16181D);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF6B7280);

  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFDEE0E6);
  static const handle = Color(0xFFD9DBE0);
  static const closeBg = Color(0xFFF1F2F4);

  static const danger = Color(0xFFD03434);
  static const dangerSoft = Color(0xFFFCEEEE);

  static const tooltipBg = Color(0xFF212630);

  /// 파란 예산 카드 위에 얹는 보조 텍스트
  static const onPrimaryMuted = Color(
    0xFFFFFFFF,
  ); // readable small text on blue
  static const onPrimaryFaint = Color(0x8CFFFFFF); // white 55%
}
