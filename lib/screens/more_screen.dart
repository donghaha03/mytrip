import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_top_bar.dart';

/// 09. 더보기.
///
/// ───────────────────────────────────────────────────────────────
///  이 파일은 "더보기 페이지" 담당자 것이다. 다른 사람은 건드리지 않는다.
///  (담당 표는 CONTRIBUTING.md 참고)
/// ───────────────────────────────────────────────────────────────
///
/// 03 메인 오른쪽 위 햄버거(≡) 를 누르면 여기로 들어온다.
///
/// 쓸 수 있는 데이터:
///   trip.name / trip.country / trip.budgetKrw / trip.start / trip.end
///   trip.dateRangeLabel  trip.durationLabel  trip.isCompleted
///   tripStore.rename(id, name)   tripStore.remove(id)
///
/// 여행 이름 편집·삭제는 이미 widgets/sheets.dart 의 TripEditSheet 에
/// 만들어져 있다 (01 리스트에서 카드를 길게 누르면 뜬다). 여기서도 쓰려면
/// `showAppSheet<TripEditResult>(...)` 를 그대로 불러 쓰면 된다 —
/// 같은 걸 새로 만들지 말 것.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTopBar(title: '더보기'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NotBuiltYet(
                      owner: '더보기 페이지',
                      hint: '여행 정보 수정(이름·기간·예산), 통화/환율 설정, 여행 삭제 같은 메뉴를 모은다.\n'
                          '앱 전체 설정이 생기면 여기에 같이 붙인다.',
                    ),
                    const SizedBox(height: 20),
                    // 데이터가 실제로 들어오는지 확인용. 구현하면서 지운다.
                    Text(
                      '${trip.name} · ${trip.dateRangeLabel}',
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
