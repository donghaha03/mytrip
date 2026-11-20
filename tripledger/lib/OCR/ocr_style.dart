import 'package:flutter/material.dart';

import '../AppColors.dart';

// OCR 화면 공통 모양. 기존 화면(여행 장부·내 정보)의 앱바·버튼·카드 기준을 따르고
// 색은 AppColors만 쓴다.

AppBar ocrAppBar(String title, {List<Widget>? actions}) => AppBar(
  title: Text(
    title,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    ),
  ),
  centerTitle: true,
  backgroundColor: AppColors.white,
  surfaceTintColor: AppColors.white,
  elevation: 0,
  actions: actions,
);

final ocrPrimaryButton = FilledButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: AppColors.white,
  minimumSize: const Size.fromHeight(54),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
);

final ocrOutlinedButton = OutlinedButton.styleFrom(
  backgroundColor: AppColors.white,
  foregroundColor: AppColors.primary,
  minimumSize: const Size.fromHeight(48),
  side: const BorderSide(color: AppColors.border),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
);

/// 버튼 안에 넣는 작은 로딩 표시.
const ocrButtonSpinner = SizedBox(
  width: 22,
  height: 22,
  child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
);

void showOcrMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// 흰 배경에 얇은 테두리가 있는 카드.
class OcrCard extends StatelessWidget {
  const OcrCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
