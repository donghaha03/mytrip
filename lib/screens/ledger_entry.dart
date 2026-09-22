import 'package:flutter/material.dart';

import '../models/trip.dart';

/// 장부 페이지를 어떤 상태로 열지. 여행 홈 하단 버튼마다 다르게 부른다.
enum LedgerStart {
  /// "여행 장부" — 남은 예산, 지출 목록
  overview,

  /// "지출 기록" — 바로 입력 폼부터
  addExpense,
}

/// 여행 홈 -> 장부 페이지 연결 지점.
///
/// 장부 페이지는 이 저장소 담당 범위 밖이다. 버튼은 먼저 보이게 두고,
/// 누르면 "준비 중" 안내만 뜬다.
///
/// ───────────────────────────────────────────────────────────────
///  장부 담당이 만들 것:
///   - 지출 목록 (최근 결제가 위로, 날짜별 묶기 등)
///   - 지출 기록 입력 (카테고리, 사용처, 금액 / 날짜는 시스템 시각)
///   - (선택) 어제 대비 증감, 카테고리별 합계
///
///  ⚠ 여행 홈에 이미 있는 것 — 장부에서 또 만들 필요 없다:
///    - 사용한 금액 · 예산 대비 진행 바 · 남은 금액 (trip_home_screen.dart)
///    - 오늘 예산 (widgets/today_budget_sheet.dart)
///    - "¥100 = ₩950 ⓘ" + 07 환율 갱신 툴팁 (widgets/rate_info_tooltip.dart)
///      장부 화면 상단에도 필요하면 RateInfoButton 을 그대로 가져다 쓰면 된다.
///    여행 홈은 trip.expenses 를 읽기만 하므로, 장부에서 tripStore.addExpense 로
///    기록하면 여행 홈 숫자는 자동으로 갱신된다.
///
///  예전 03 구현(지출 목록 한 줄 위젯 ExpenseTile 포함)을 참고해도 된다:
///   git show 6fe2ac6:lib/screens/trip_main_screen.dart
///   git show 6fe2ac6:lib/widgets/budget_card.dart         (ExpenseTile)
///
///  연결은 이 파일만 고치면 된다. 여행 홈 화면은 건드릴 필요 없다.
///   1. lib/screens/ledger_screen.dart 에 LedgerScreen(trip:, start:) 을 만든다
///   2. 아래 [kLedgerReady] 를 true 로 -> 버튼의 "준비 중" 표시가 사라진다
///   3. [openLedger] 안의 주석 처리된 push 를 살리고 import 를 추가한다
///
///  쓸 수 있는 것:
///   trip.expensesNewestFirst               최신순 지출 목록
///   trip.spentKrw / remainKrw / spentRatio 합계·남은 예산·비율
///   trip.country.formatForeign(e.amount)   "¥1,200"
///   trip.country.toKrw(e.amount)           원화 환산
///   trip.country.rateLabel                 "¥100 = ₩950"
///   tripStore.addExpense(trip.id, Expense(...))  저장 (Firebase 모드면 Firestore 까지)
/// ───────────────────────────────────────────────────────────────
const bool kLedgerReady = false;

void openLedger(
  BuildContext context,
  Trip trip, {
  LedgerStart start = LedgerStart.overview,
}) {
  if (kLedgerReady) {
    // Navigator.of(context).push(MaterialPageRoute(
    //     builder: (_) => LedgerScreen(trip: trip, start: start)));
    return;
  }
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
