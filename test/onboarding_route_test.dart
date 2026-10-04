import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/trip_home/app.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/screens/empty_home_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/screens/trip_list_screen.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';
import 'package:tripapp/trip_home/widgets/departure_map.dart';
import 'package:tripapp/trip_home/widgets/departure_map_data.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tripStore.connect(null);
  });
  tearDown(() => tripStore.connect(null));

  for (final ongoing in [true, false]) {
    testWidgets(
      'first run shows guide before ${ongoing ? 'ongoing' : 'upcoming'} trip, then remembers it',
      (tester) async {
        final now = DateTime.now();
        tripStore.add(
          Trip(
            id: 'completed',
            name: '지난 여행',
            country: countryByIso('US')!,
            start: now.subtract(const Duration(days: 10)),
            end: now.subtract(const Duration(days: 8)),
            budgetKrw: 100000,
          ),
        );
        final t = Trip(
          id: 'first-run',
          name: '태국 여행',
          country: countryByIso('TH')!,
          start: ongoing ? now : now.add(const Duration(days: 20)),
          end: now.add(Duration(days: ongoing ? 2 : 22)),
          budgetKrw: 100000,
        );
        tripStore.add(t);
        await tester.pumpWidget(const TripApp());
        await tester.pumpAndSettle();
        expect(find.text('앱 사용방법'), findsOneWidget);
        expect(find.byType(TripHomeScreen), findsNothing);
        expect(find.byType(TripListScreen), findsNothing);
        expect(
          tester
              .widget<EmptyHomeScreen>(find.byType(EmptyHomeScreen))
              .destination!
              .code,
          'TH',
        );
        await tester.tap(find.text('건너뛰기'));
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
    'first empty run ends at welcome and skips guide on next launch',
    (tester) async {
      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();
      expect(find.text('앱 사용방법'), findsOneWidget);
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();
      expect(find.text('여행을 추가해요'), findsNothing);
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
    },
  );

  test(
    'all destinations have bounded coordinates; labels use mainland US and France',
    () {
      for (final country in [...kCountries, kPrimaryCountries[2]]) {
        final coordinate = departureCoordinates[country.code];
        expect(coordinate, isNotNull, reason: country.code);
        expect(coordinate!.$1, inInclusiveRange(-180, 180));
        expect(coordinate.$2, inInclusiveRange(-90, 90));
        for (final size in [const Size(272, 240), const Size(392, 240)]) {
          final route = DepartureRoute(size, country.code);
          for (final point in [route.start, route.end]) {
            expect(point.dx, inInclusiveRange(16, size.width - 16));
            expect(point.dy, inInclusiveRange(16, size.height - 16));
          }
        }
      }
      expect(departureCoordinates['US']!.$1, inInclusiveRange(-125, -65));
      expect(departureCoordinates['FR']!.$1, inInclusiveRange(-5, 10));
      expect(
        DepartureRoute(const Size(340, 240), 'US').end.dx,
        greaterThan(DepartureRoute(const Size(340, 240), 'US').start.dx),
      );
      expect(DepartureRoute(const Size(340, 240), 'KR').hasFlight, isFalse);
      expect(DepartureRoute(const Size(340, 240), 'XX').hasFlight, isFalse);
      for (final ring in departureLand) {
        expect(ring.length.isEven, isTrue);
        expect(ring.every((v) => v.isFinite), isTrue);
      }
    },
  );

  for (final size in [const Size(320, 480), const Size(812, 375)]) {
    testWidgets('destination map departure fits $size with large text', (
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
          home: EmptyHomeScreen(destination: countryByIso('US')),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('다음 안내'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }
      await tester.tap(find.byTooltip('출발하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DepartureMap), findsOneWidget);
      expect(find.text('한국 → 미국'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byType(DepartureMap), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
