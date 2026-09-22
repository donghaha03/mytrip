import 'package:flutter/material.dart';

import '../models/trip.dart';

/// 03 메인의 "여행 장부" 메뉴 -> 장부 페이지 연결 지점.
///
/// 장부 페이지는 아직 없다 (이 저장소의 담당 범위 밖). 메뉴는 먼저 보이게 두고,
/// 누르면 "준비 중" 안내만 뜬다.
///
/// ───────────────────────────────────────────────────────────────
///  장부 페이지를 만드는 사람은 이 파일만 고치면 된다.
///  trip_main_screen.dart(공용)는 건드릴 필요 없다.
///
///   1. lib/screens/ledger_screen.dart 에 LedgerScreen(trip: trip) 을 만든다
///   2. 아래 [kLedgerReady] 를 true 로 바꾼다 -> 메뉴의 "준비 중" 표시가 사라진다
///   3. [openLedger] 안의 주석 처리된 push 두 줄을 살리고 import 를 추가한다
///
///  쓸 수 있는 것:
///   trip.expensesNewestFirst               최신순 지출 목록
///   trip.country.formatForeign(e.amount)   "¥1,200"
///   trip.country.toKrw(e.amount)           원화 환산
///   tripStore.addExpense(trip.id, Expense(...))  저장 (Firebase 모드면 Firestore 까지)
/// ───────────────────────────────────────────────────────────────
const bool kLedgerReady = false;

void openLedger(BuildContext context, Trip trip) {
  if (kLedgerReady) {
    // Navigator.of(context).push(
    //     MaterialPageRoute(builder: (_) => LedgerScreen(trip: trip)));
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('장부 페이지는 준비 중이에요'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
}
