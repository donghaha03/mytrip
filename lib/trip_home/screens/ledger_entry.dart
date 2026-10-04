import 'package:flutter/material.dart';

import '../models/trip.dart';
import 'expense_form_screen.dart';
import 'ledger_screen.dart';

/// 장부 요약 또는 지출 입력으로 진입할 목적.
enum LedgerStart { overview, addExpense, receipt }

/// 전체 보기·장부 보기와 지출 기록이 공유하는 진입점.
void openLedger(
  BuildContext context,
  Trip trip, {
  LedgerStart start = LedgerStart.overview,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => start != LedgerStart.overview
          ? ExpenseFormScreen(
              trip: trip,
              startWithReceipt: start == LedgerStart.receipt,
            )
          : LedgerScreen(trip: trip),
    ),
  );
}
