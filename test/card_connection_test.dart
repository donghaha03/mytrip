import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart' show CardSyncApi;
import 'package:tripapp/ledger/models/country.dart';
import 'package:tripapp/ledger/models/trip.dart';
import 'package:tripapp/ledger/theme/app_theme.dart';
import 'package:tripapp/trip_home/screens/card_connection_screen.dart';

Widget wrap(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);
http.Response response(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, Object> status({bool connected = false, bool otherTrip = false}) =>
    {
      'consentVersion': CardSyncApi.consentVersion,
      'connected': connected,
      'pending': false,
      'otherTrip': otherTrip,
      'revoking': false,
      'automatic': false,
      'cards': <Object>[],
      'cardName': connected ? '본인 카드' : '',
      'masked': connected ? '•••• 5678' : '',
    };

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<TextEditingController> fillAuthentication(WidgetTester tester) async {
  final id = find.byKey(const ValueKey('card-login-id'));
  final password = find.byKey(const ValueKey('card-login-password'));
  await tester.ensureVisible(id);
  await tester.enterText(id, 'test-issuer-user');
  await tester.ensureVisible(password);
  await tester.enterText(password, 'test-issuer-password');
  final controller = tester.widget<TextFormField>(password).controller!;
  await tapVisible(tester, find.byKey(const ValueKey('card-consent')));
  return controller;
}

void main() {
  final trip = Trip(
    id: 't1',
    name: '일본 여행',
    country: countryByCode('JPY')!,
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 5),
    budgetKrw: 100000,
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('카드 인증→실제 응답 카드 선택→조회→철회 흐름을 검사한다', (tester) async {
    var connected = false;
    var queries = 0;
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['Authorization'], startsWith('Bearer '));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['tripId'], 't1');
      expect(body.containsKey('uid'), isFalse);
      switch (request.url.path) {
        case '/connection/status':
          return response(status(connected: connected));
        case '/connection/authenticate':
          expect(body['consent'], isTrue);
          expect(body['organization'], '0303');
          expect(body['loginId'], 'test-issuer-user');
          expect(body['password'], 'test-issuer-password');
          return response({
            'cards': [
              {'key': 'owned-card-key', 'name': '본인 카드', 'masked': '•••• 5678'},
            ],
          });
        case '/connection/select':
          expect(body['cardKey'], 'owned-card-key');
          expect(body.containsKey('cardNo'), isFalse);
          connected = true;
          return response({'connected': true});
        case '/sync':
          queries++;
          return response({'received': 1, 'skipped': 0});
        case '/connection/disconnect':
          connected = false;
          return response({'connected': false});
        default:
          throw StateError('예상하지 못한 API');
      }
    });
    await tester.pumpWidget(
      wrap(
        CardConnectionScreen(
          trip: trip,
          currentUid: () => 'u1',
          idToken: () async => 'test-token',
          userChanges: const Stream.empty(),
          client: client,
          server: Uri.parse('https://cards.example.invalid/'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('card-authenticate')))
          .onPressed,
      isNull,
    );
    final password = await fillAuthentication(tester);
    await tapVisible(tester, find.byKey(const ValueKey('card-authenticate')));
    expect(password.text, isEmpty);
    expect(find.text('본인 카드'), findsOneWidget);
    expect(find.text('실제 카드 미연결'), findsOneWidget);
    expect(queries, 0);
    await tapVisible(tester, find.text('본인 카드'));
    await tapVisible(tester, find.text('선택한 카드 연결'));
    expect(find.text('본인 카드 •••• 5678'), findsOneWidget);
    expect(queries, 1);
    expect(find.textContaining('자동 조회는 꺼져'), findsOneWidget);
    await tapVisible(tester, find.text('연결 해제'));
    await tester.tap(find.widgetWithText(TextButton, '연결 해제').last);
    await tester.pumpAndSettle();
    expect(connected, isFalse);
    expect(find.text('실제 카드 미연결'), findsOneWidget);
    expect(paths.where((path) => path == '/connection/authenticate').length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('카드사 인증 오류는 재시도하거나 연결 성공으로 표시하지 않고 비밀번호를 비운다', (tester) async {
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/status')) return response(status());
      attempts++;
      return http.Response('{"error":"provider-secret"}', 422);
    });
    await tester.pumpWidget(
      wrap(
        CardConnectionScreen(
          trip: trip,
          currentUid: () => 'u1',
          idToken: () async => 'test-token',
          userChanges: const Stream.empty(),
          client: client,
          server: Uri.parse('https://cards.example.invalid'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final password = await fillAuthentication(tester);
    await tapVisible(tester, find.byKey(const ValueKey('card-authenticate')));
    expect(password.text, isEmpty);
    expect(attempts, 1);
    await tester.scrollUntilVisible(
      find.textContaining('반복 입력하지 말고'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('provider-secret'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('실제 카드 미연결'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('실제 카드 미연결'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('카드 인증은 HTTPS만 허용하고 제공자 원문 오류를 표시하지 않는다', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('secret', 403);
    });
    for (final url in [
      'http://cards.example.invalid',
      'ftp://localhost',
      'https://user:password@example.invalid',
    ]) {
      await expectLater(
        CardSyncApi.connection(
          action: 'authenticate',
          tripId: 't1',
          idToken: 'test-token',
          base: Uri.parse(url),
          client: client,
        ),
        throwsStateError,
      );
    }
    expect(calls, 0);
    await expectLater(
      CardSyncApi.connection(
        action: 'status',
        idToken: 'test-token',
        base: Uri.parse('https://cards.example.invalid'),
        client: client,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('승인한 테스트 계정'),
        ),
      ),
    );
    expect(calls, 1);
  });
}
