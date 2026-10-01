import 'package:flutter/material.dart';

import '../models/trip.dart';

/// 장부 요약 또는 지출 입력으로 진입할 목적.
enum LedgerStart { overview, addExpense }

/// 팀 장부 화면과 연결할 지점. 현재는 준비 중 안내만 표시한다.
/// 연결 기준은 CONTRIBUTING.md를 참고한다.
void openLedger(
  BuildContext context,
  Trip trip, {
  LedgerStart start = LedgerStart.overview,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          start == LedgerStart.addExpense
              ? '지출 기록은 장부 페이지에서 할 수 있어요 (준비 중)'
              : '장부 페이지는 준비 중이에요',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}
