import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripapp/login_screen.dart';

void main() {
  testWidgets('팀 로그인 화면을 열고 빈 입력은 서버 호출 전에 안내한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.byType(LoginScreen), findsOneWidget);
    final login = find.widgetWithText(ElevatedButton, '로그인');
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('이메일을 입력해주세요'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
