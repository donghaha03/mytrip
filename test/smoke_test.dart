import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripapp/data/trip_store.dart';
import 'package:tripapp/main.dart';
import 'package:tripapp/screens/add_trip_screen.dart';
import 'package:tripapp/screens/trip_list_screen.dart';
import 'package:tripapp/screens/trip_main_screen.dart';
import 'package:tripapp/theme/app_theme.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: buildAppTheme(), home: child);

void main() {
  // 목업 스크린샷과 같은 폰 사이즈로 맞춘다 (iPhone 14 기준).
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('00 빈 화면이 그려진다', (tester) async {
    await tester.pumpWidget(const TripApp());
    expect(find.text('아직 떠날 준비가 남았어요'), findsOneWidget);
    expect(find.text('여행 추가하기'), findsOneWidget);
    expect(find.text('자동 환산'), findsOneWidget);
  });

  testWidgets('01 여행 리스트 + 여행완료 도장', (tester) async {
    tripStore.seedMockTrips();
    await tester.pumpWidget(const TripApp());
    expect(find.text('내 여행'), findsOneWidget);
    expect(find.text('일본 여행'), findsOneWidget);
    expect(find.text('가족 여행'), findsOneWidget);
    // 미국 여행만 종료일이 지났다
    expect(find.text('여행완료'), findsOneWidget);
  });

  testWidgets('02 새 여행 추가 화면', (tester) async {
    await tester.pumpWidget(_wrap(const AddTripScreen()));
    expect(find.text('새 여행 추가'), findsOneWidget);
    expect(find.text('JPY'), findsOneWidget);
    expect(find.text('더보기'), findsOneWidget);
    expect(find.text('여행 만들기'), findsOneWidget);
  });

  testWidgets('03 메인 페이지 예산 카드 + 최근 지출', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripMainScreen(trip: japan)));
    expect(find.text('남은 예산'), findsOneWidget);
    expect(find.text('100엔 = 950원'), findsOneWidget);
    expect(find.text('📒  여행 장부 보기'), findsOneWidget);
    expect(find.text('이치란 라멘'), findsOneWidget);
    expect(find.text('11,400원'), findsOneWidget); // ¥1,200 환산
  });

  testWidgets('04 국가 더보기 시트', (tester) async {
    await tester.pumpWidget(_wrap(const AddTripScreen()));
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('국가 더보기'), findsOneWidget);
    expect(find.text('HKD'), findsOneWidget);

    await tester.tap(find.text('SGD'));
    await tester.pump();
    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
    // 그리드 마지막 칸이 고른 국가로 바뀐다
    expect(find.text('SGD'), findsOneWidget);
  });

  testWidgets('05 기간 선택 시트 - 드래그로 범위 지정', (tester) async {
    await tester.pumpWidget(_wrap(const AddTripScreen()));
    await tester.tap(find.text('출발일'));
    await tester.pumpAndSettle();

    expect(find.text('여행 기간 선택'), findsOneWidget);
    expect(find.text('날짜를 드래그해 기간을 정해 주세요'), findsOneWidget);

    // 1일에서 5일까지 드래그
    await tester.drag(find.text('1'), const Offset(160, 40));
    await tester.pumpAndSettle();
    expect(find.textContaining('박'), findsOneWidget);
  });

  testWidgets('06 여행 편집 시트 - 이름 변경', (tester) async {
    await tester.pumpWidget(_wrap(const TripListScreen()));
    await tester.longPress(find.text('가족 여행'));
    await tester.pumpAndSettle();

    expect(find.text('여행 편집'), findsOneWidget);
    expect(find.text('여행 삭제'), findsOneWidget);
    expect(find.text('5 / 20자'), findsOneWidget); // '가족 여행'

    await tester.enterText(find.byType(TextField), '방콕 여행');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('방콕 여행'), findsOneWidget);
    expect(find.text('가족 여행'), findsNothing);
  });

  testWidgets('03 뒤로가기로 01 리스트에 돌아온다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();
    expect(find.text('남은 예산'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('내 여행'), findsOneWidget);
  });

  testWidgets('03 을 루트로 띄우면 뒤로가기가 없다', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripMainScreen(trip: japan)));
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('03 이름이 최대 길이여도 상단바가 안 넘친다', (tester) async {
    // 뒤로가기 + 국기 + 이름(20자) + 환율 + i + 햄버거가 한 줄에 들어가야 한다.
    // 넘치면 RenderFlex overflow 로 이 테스트가 깨진다.
    final trip = tripStore.trips.firstWhere((t) => t.id == 't1'); // 1달러 = 1,350원
    tripStore.rename(trip.id, '가' * 20);
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('가' * 20));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('1달러 = 1,350원'), findsOneWidget);
  });

  testWidgets('07 환율 정보 툴팁', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripMainScreen(trip: japan)));

    await tester.tap(find.text('i'));
    await tester.pumpAndSettle();
    expect(find.text('환율 갱신 정보'), findsOneWidget);
    expect(find.text('환율은 24시간마다 한 번 갱신돼요'), findsOneWidget);
  });

  test('환율 환산 / 포맷', () {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    // 100엔 = 950원 이므로 ¥1,200 -> 11,400원
    expect(japan.country.toKrw(1200), 11400);
    expect(japan.country.rateLabel, '100엔 = 950원');
    expect(formatWon(742300), '742,300원');
    expect(formatNumber(-1234567), '-1,234,567');
  });
}
