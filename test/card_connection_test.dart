import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/trip_home/data/trip_repository.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/screens/card_connection_screen.dart';
import 'package:tripapp/trip_home/screens/empty_home_screen.dart';
import 'package:tripapp/trip_home/screens/more_screen.dart';
import 'package:tripapp/trip_home/services/auth_service.dart';
import 'package:tripapp/trip_home/services/backend.dart';
import 'package:tripapp/trip_home/services/card_sync_api.dart';
import 'package:tripapp/trip_home/services/session.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';

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
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth firebase;
  late Trip trip;
  late AuthService oldAuth;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    oldAuth = authService;
    Backend.mode = BackendMode.firebase;
    db = FakeFirebaseFirestore();
    firebase = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'test@example.invalid'),
    );
    final repository = FirestoreTripRepository(uid: 'u1', db: db);
    await repository.saveTrip(
      Trip(
        id: 't1',
        name: '일본 여행',
        country: countryByCode('JPY')!,
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 5),
        budgetKrw: 100000,
      ),
    );
    tripStore.connect(repository);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    trip = tripStore.trips.single;
  });
  tearDown(() {
    tripStore.connect(null);
    Backend.mode = BackendMode.local;
    authService = oldAuth;
  });

  testWidgets('더보기 카드 인증→실제 응답 카드 선택→장부 구독→철회 흐름을 검사한다', (tester) async {
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
          await db
              .collection('users')
              .doc('u1')
              .collection('trips')
              .doc('t1')
              .collection('records')
              .doc('card_test')
              .set({
                'place': '승인된 편의점',
                'amount': 1000,
                'currency': 'KRW',
                'date': Timestamp.fromDate(DateTime(2026, 10, 3, 12)),
                'paymentMethod': 'card',
                'source': 'codef',
                'status': 'approved',
                'originalAmount': 1000,
              });
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
          auth: firebase,
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
    expect(trip.expenses.single.place, '승인된 편의점');
    expect(trip.expenses.single.source, 'codef');
    expect(find.textContaining('자동 조회는 꺼져'), findsOneWidget);
    await tapVisible(tester, find.text('연결 해제'));
    await tester.tap(find.widgetWithText(TextButton, '연결 해제').last);
    await tester.pumpAndSettle();
    expect(connected, isFalse);
    expect(find.text('실제 카드 미연결'), findsOneWidget);
    expect(trip.expenses.single.place, '승인된 편의점');
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
          auth: firebase,
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
    expect(trip.expenses, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('여행이 없어도 더보기에서 기존 연결을 해제할 수 있다', (tester) async {
    tripStore.connect(
      FirestoreTripRepository(uid: 'u1', db: FakeFirebaseFirestore()),
    );
    var linked = true;
    final client = MockClient((request) async {
      expect(jsonDecode(request.body), <String, Object>{});
      if (request.url.path.endsWith('/status')) {
        return response(status(otherTrip: linked));
      }
      expect(request.url.path, '/connection/disconnect');
      linked = false;
      return response({'connected': false});
    });
    await tester.pumpWidget(
      wrap(
        CardConnectionScreen(
          auth: firebase,
          client: client,
          server: Uri.parse('https://cards.example.invalid'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('연결 해제'));
    await tester.tap(find.widgetWithText(TextButton, '연결 해제').last);
    await tester.pumpAndSettle();
    expect(linked, isFalse);
    expect(find.textContaining('여행을 추가하고 선택'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('더보기 메뉴 제거 후에도 기존 인증 저장소의 연결·해제는 보존한다', (tester) async {
    final service = FirebaseAuthService(
      MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'test@example.invalid'),
      ),
    );
    authService = service;
    bindTripStoreToAuth(
      service,
      tripStore,
      repoFor: (uid) => FirestoreTripRepository(uid: uid, db: db),
    );
    await tester.pumpWidget(wrap(const MoreScreen()));
    await tester.pumpAndSettle();
    expect(find.text('mytrip 로그인'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await service.signIn('test@example.invalid', 'test-mytrip-password');
    await tester.pumpAndSettle();
    expect(find.text('test@example.invalid'), findsNothing);
    expect(tripStore.trips.single.id, 't1');
    await service.signOut();
    await tester.pumpAndSettle();
    expect(tripStore.isEmpty, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('여행 없는 첫 화면의 더보기도 로그인·카드 없는 빈 화면이다', (tester) async {
    Backend.mode = BackendMode.local;
    tripStore.connect(null);
    await tester.pumpWidget(wrap(const EmptyHomeScreen()));
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.byType(CardConnectionScreen), findsNothing);
    expect(find.text('카드 연동'), findsNothing);
    expect(find.text('mytrip 로그인'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('인증 도중 계정이 바뀌면 이전 계정의 카드 응답을 표시하지 않는다', (tester) async {
    final pending = Completer<http.Response>();
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/status')) return response(status());
      attempts++;
      return pending.future;
    });
    await tester.pumpWidget(
      wrap(
        CardConnectionScreen(
          trip: trip,
          auth: firebase,
          client: client,
          server: Uri.parse('https://cards.example.invalid'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final password = await fillAuthentication(tester);
    await tester.tap(find.byKey(const ValueKey('card-authenticate')));
    await tester.pump();
    expect(attempts, 1);
    await firebase.signOut();
    tripStore.connect(null);
    pending.complete(
      response({
        'cards': [
          {'key': 'old-card', 'name': '이전 계정 카드', 'masked': '•••• 1234'},
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('이전 계정 카드'), findsNothing);
    expect(password.text, isEmpty);
    expect(find.text('선택한 카드 연결'), findsNothing);
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
