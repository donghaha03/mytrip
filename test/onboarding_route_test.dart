import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/ledger/receipts/receipt_consent.dart';
import 'package:tripapp/ledger/theme/app_theme.dart';
import 'package:tripapp/trip_home/screens/empty_home_screen.dart';

// 첫 실행 안내와 영수증 동의 화면. 로그인·여행 목록과의 연결은 trip_home_test.dart.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 480), const Size(812, 375)]) {
    testWidgets(
      'consent details and decision stay reachable with large text at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: ReceiptConsentScreen(
              url: Uri.parse(receiptServerOrigin),
              onDecision: (_) {},
            ),
          ),
        );
        await tester.scrollUntilVisible(find.text('전송·보관·이용 한도 안내'), 100);
        await tester.ensureVisible(find.text('전송·보관·이용 한도 안내'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('전송·보관·이용 한도 안내'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('동의하지 않고 직접 입력하기'), 150);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('동의 화면은 Anthropic 기준으로 안내하고 Google 문구를 쓰지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ReceiptConsentScreen(
          url: Uri.parse(receiptServerOrigin),
          onDecision: (_) {},
        ),
      ),
    );
    expect(receiptConsentVersion, 'claude-haiku-v1');
    expect(find.textContaining('Anthropic의 Claude'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('전송·보관·이용 한도 안내'), 100);
    await tester.tap(find.text('전송·보관·이용 한도 안내'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Anthropic 상용 약관'), 100);
    expect(find.textContaining('하루 200건'), findsOneWidget);
    for (final gone in ['Google', 'Gemini', '무료', '유럽']) {
      expect(find.textContaining(gone), findsNothing, reason: gone);
    }
  });
  for (final size in [const Size(320, 480), const Size(812, 375)]) {
    testWidgets('five guide pages finish directly at welcome at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const EmptyHomeScreen(),
        ),
      );
      expect(
        tester
            .widget<PageView>(find.byType(PageView))
            .childrenDelegate
            .estimatedChildCount,
        5,
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('다음 안내'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }
      await tester.tap(find.byTooltip('시작하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      expect(find.byType(PageView), findsNothing);
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      expect(find.byIcon(Icons.flight_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('final left swipe finishes once on $platform', (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme().copyWith(platform: platform),
          home: EmptyHomeScreen(onGuideFinished: () => completed++),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('다음 안내'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
