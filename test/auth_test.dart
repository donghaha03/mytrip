// 로그인 화면 -> 앱 -> 로그아웃 흐름 (로컬 임시 모드).
// 로그인 담당이 화면을 갈아엎어도 이 흐름은 유지돼야 한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripapp/data/trip_store.dart';
import 'package:tripapp/main.dart';
import 'package:tripapp/screens/login_screen.dart';
import 'package:tripapp/screens/more_screen.dart';
import 'package:tripapp/services/auth_service.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
    authService = LocalAuthService();
    tripStore.seedMockTrips();
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('로그인 안 하면 로그인 화면부터 뜬다', (tester) async {
    await tester.pumpWidget(const TripApp());
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('내 여행'), findsNothing);
  });

  testWidgets('비밀번호가 짧으면 에러를 보여주고 안 넘어간다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.enterText(find.byType(TextField).at(0), 'a@a.com');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('비밀번호는 6자 이상이어야 해요'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('로그인하면 여행 목록으로, 더보기에서 로그아웃하면 로그인으로', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.enterText(find.byType(TextField).at(0), 'a@a.com');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.text('내 여행'), findsOneWidget);

    // 01 -> 03 -> 더보기 까지 화면을 쌓은 다음 로그아웃
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    // 쌓여 있던 03·더보기가 전부 걷히고 로그인 화면만 남아야 한다
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MoreScreen), findsNothing);
    expect(find.text('남은 예산'), findsNothing);
  });

  testWidgets('회원가입 모드로 전환된다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('처음이에요 · 회원가입'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '회원가입'), findsOneWidget);
  });
}
