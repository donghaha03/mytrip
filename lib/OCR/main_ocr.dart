import 'package:flutter/material.dart';

import '../AppColors.dart';
import 'ocr_screen.dart';

/// 영수증 인식(OCR) 단독 실행 진입점. 기존 앱 화면과 연결하지 않는다.
///
///   flutter run -t lib/OCR/main_ocr.dart
///
/// Firebase를 쓰지 않으므로 초기화도 로그인도 필요 없다.
void main() => runApp(const OcrApp());

class OcrApp extends StatelessWidget {
  const OcrApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '영수증 인식',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    ),
    home: const OcrScreen(),
  );
}
