import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/trip_home/app.dart';
import 'package:tripapp/trip_home/receipts/receipt_consent.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/screens/empty_home_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/screens/trip_list_screen.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      receiptConsentKey(Uri.parse(receiptServerOrigin)): true,
    });
    tripStore.connect(null);
  });
  tearDown(() => tripStore.connect(null));
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
        await tester.scrollUntilVisible(find.text('전송·보관·무료 사용 안내'), 100);
        await tester.ensureVisible(find.text('전송·보관·무료 사용 안내'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('전송·보관·무료 사용 안내'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('동의하지 않고 직접 입력하기'), 150);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final accept in [null, true, false]) {
    testWidgets(
      'startup never requests receipt consent (stored decision $accept)',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          receiptConsentKey(Uri.parse(receiptServerOrigin)): ?accept,
        });
        await tester.pumpWidget(const TripApp());
        await tester.pumpAndSettle();
        expect(find.text('앱 사용방법'), findsOneWidget);
        await tester.tap(find.text('건너뛰기'));
        await tester.pumpAndSettle();
        expect(find.text('영수증 인식 안내'), findsNothing);
        expect(await receiptConsent(Uri.parse(receiptServerOrigin)), accept);
        expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(const TripApp());
        await tester.pumpAndSettle();
        expect(find.text('영수증 인식 안내'), findsNothing);
        expect(find.text('앱 사용방법'), findsNothing);
      },
    );
  }
  for (final ongoing in [true, false]) {
    testWidgets(
      'first run guide precedes ${ongoing ? 'ongoing' : 'upcoming'} trip and is remembered',
      (tester) async {
        final now = DateTime.now();
        tripStore.add(
          Trip(
            id: 'first-run',
            name: '태국 여행',
            country: countryByIso('TH')!,
            start: ongoing ? now : now.add(const Duration(days: 20)),
            end: now.add(Duration(days: ongoing ? 2 : 22)),
            budgetKrw: 100000,
          ),
        );
        await tester.pumpWidget(const TripApp());
        await tester.pumpAndSettle();
        expect(find.text('앱 사용방법'), findsOneWidget);
        expect(find.byType(TripHomeScreen), findsNothing);
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byTooltip('다음 안내'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
        }
        await tester.tap(find.byTooltip('시작하기'));
        await tester.pumpAndSettle();
        expect(
          find.byType(ongoing ? TripHomeScreen : TripListScreen),
          findsOneWidget,
        );
        expect(
          (await SharedPreferences.getInstance()).getBool('trip_guide_seen'),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(const TripApp());
        await tester.pumpAndSettle();
        expect(find.text('앱 사용방법'), findsNothing);
        expect(
          find.byType(ongoing ? TripHomeScreen : TripListScreen),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'first empty launch leads to welcome and skips the guide on relaunch',
    (tester) async {
      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();
      expect(find.text('앱 사용방법'), findsNothing);
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
    },
  );
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
