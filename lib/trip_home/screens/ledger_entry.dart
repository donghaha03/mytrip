import 'package:flutter/material.dart';

import '../../ledger/data/trip_store.dart';
import '../../ledger/models/trip.dart';
import '../../ledger/screens/expense_form_screen.dart';
import '../../ledger/screens/ledger_screen.dart';
import 'more_screen.dart';

/// 장부 요약 또는 지출 입력으로 진입할 목적.
enum LedgerStart { overview, addExpense, receipt }

/// 전체 보기·장부 보기와 지출 기록이 공유하는 진입점.
/// 여행 홈이 이미 가진 [store]를 그대로 넘겨 같은 값을 본다.
/// (여행 ID만 알 때는 `LedgerPage(tripId:)`를 쓴다.)
void openLedger(
  BuildContext context,
  Trip trip,
  TripStore store, {
  LedgerStart start = LedgerStart.overview,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => start != LedgerStart.overview
          ? ExpenseFormScreen(
              trip: trip,
              store: store,
              startWithReceipt: start == LedgerStart.receipt,
            )
          : LedgerScreen(
              trip: trip,
              store: store,
              onMore: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MoreScreen()),
              ),
            ),
    ),
  );
}
