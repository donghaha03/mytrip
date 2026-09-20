import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';

/// 08. 여행 장부 상세.
///
/// ───────────────────────────────────────────────────────────────
///  이 파일은 "장부 페이지" 담당자 것이다. 다른 사람은 건드리지 않는다.
///  (담당 표는 CONTRIBUTING.md 참고)
/// ───────────────────────────────────────────────────────────────
///
/// 03 메인의 "📒 여행 장부 보기" 를 누르면 여기로 들어온다.
/// 03 은 최근 3건만 보여주고, 여기서 전체를 다룬다.
///
/// 쓸 수 있는 데이터 (models/trip.dart):
///   trip.expensesNewestFirst   최신순 정렬된 `List<Expense>`
///   trip.expenses              원본 리스트
///   e.icon / e.place / e.amount / e.date / e.category
///   trip.country.formatForeign(e.amount)   -> "¥1,200"
///   trip.country.toKrw(e.amount)           -> 원화 double
///   formatWon(...)  formatDate(...)        -> theme/app_theme.dart
///
/// 지출 추가는 data/trip_store.dart 의
///   tripStore.addExpense(tripId, Expense(...))
/// 를 부르면 화면이 알아서 다시 그려진다 (ChangeNotifier).
class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenTopBar(title: '${trip.country.flag} ${trip.name} 장부'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NotBuiltYet(
                      owner: '장부 페이지',
                      hint: '전체 지출 내역을 날짜별로 묶어서 보여주고, 지출을 추가·수정·삭제할 수 있게 만든다.\n'
                          '카테고리별 합계나 일자별 합계도 여기에서 다룬다.',
                    ),
                    const SizedBox(height: 20),
                    // 데이터가 실제로 들어오는지 확인용. 구현하면서 지운다.
                    Text(
                      '기록된 지출 ${trip.expenses.length}건',
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
