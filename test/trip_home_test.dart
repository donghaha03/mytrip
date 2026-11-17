import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart' as api;
import 'package:tripapp/ledger/data/trip_store.dart';
import 'package:tripapp/ledger/screens/expense_form_screen.dart';
import 'package:tripapp/ledger/screens/ledger_screen.dart';
import 'package:tripapp/login_screen.dart';
import 'package:tripapp/trip_home/app.dart';
import 'package:tripapp/trip_home/data/trip_list_store.dart';
import 'package:tripapp/trip_home/screens/add_trip_screen.dart';
import 'package:tripapp/trip_home/screens/more_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/screens/trip_list_screen.dart';

import 'support/fake_firebase.dart';

/// 여행 목록·여행 홈이 팀 API(AuthApi·TripApi·ExpenseApi)로 동작하는지 본다.
/// 실제 API가 가짜 Firebase 위에서 돈다.
void main() {
  final (auth: testAuth, :firestore) = installFakeFirebase();
  const trips = 'users/owner/trips';
  final now = DateTime.now();

  void seedTrip(
    String id, {
    String name = '도쿄 여행',
    int startIn = 10,
    int endIn = 14,
  }) => firestore.documents['$trips/$id'] = api.Trip(
    id: id,
    name: name,
    budget: 1000000,
    currency: 'JPY',
    start: now.add(Duration(days: startIn)),
    end: now.add(Duration(days: endIn)),
  ).toMap();

  void seedExpense(String tripId) =>
      firestore.documents['$trips/$tripId/expenses/ramen'] = api.Expense(
        id: 'ramen',
        category: '식비',
        place: '이치란 라멘',
        amount: 1200,
        currency: 'JPY',
        rate: 9.5,
        date: now.subtract(const Duration(hours: 1)),
      ).toMap();

  setUp(() async {
    firestore.documents.clear();
    testAuth.signedIn = true;
    SharedPreferences.setMockInitialValues({
      'trip_guide_seen': true,
      'rates': jsonEncode({'JPY': 0.1, 'USD': 1 / 1500, 'KRW': 1}),
      'rates_time': now.toIso8601String(),
    });
    await api.RateApi.load();
    // 폰 크기(iPhone 14 기준)로 맞춘다.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('로그인 여부에 따라 AuthGate가 화면을 바꾸고 더보기에서 로그아웃한다', (tester) async {
    testAuth.signedIn = false;
    await launch(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('첫 여행을 추가해 보세요'), findsNothing);

    testAuth.signedIn = true;
    testAuth.events.add(testAuth.user);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);

    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('more-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('첫 실행 안내는 한 번만 보이고 여행보다 먼저 나온다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    seedTrip('tokyo');
    await launch(tester);
    expect(find.text('앱 사용방법'), findsOneWidget);
    expect(find.byType(TripListScreen), findsNothing);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.byType(TripListScreen), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool('trip_guide_seen'),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    expect(find.text('앱 사용방법'), findsNothing);
    expect(find.byType(TripListScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('새 여행은 TripApi로 저장되고 목록에 나타난다', (tester) async {
    await launch(tester);
    await tester.tap(find.text('여행 추가하기'));
    await tester.pumpAndSettle();
    expect(find.byType(AddTripScreen), findsOneWidget);

    await tester.tap(find.text('JPY'));
    await tester.pump();
    await tester.tap(find.text('출발일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('선택 완료'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1200000');
    await tester.pump();
    await tester.tap(find.text('여행 만들기'));
    await tester.pumpAndSettle();

    final saved = firestore.documents.entries.single;
    expect(saved.key, startsWith('$trips/'));
    expect(saved.value['name'], '일본 여행');
    expect(saved.value['currency'], 'JPY');
    expect(saved.value['budget'], 1200000);
    expect(find.byType(AddTripScreen), findsNothing);
    // 목록(또는 오늘이 기간 안이면 자동으로 열린 여행 홈)에 새 여행이 보인다.
    expect(find.textContaining('일본 여행'), findsWidgets);
    await close(tester);
  });

  testWidgets('목록에서 연 여행 홈과 장부가 같은 지출을 보고, 지출 기록은 ExpenseApi로 저장된다', (
    tester,
  ) async {
    seedTrip('tokyo');
    seedExpense('tokyo');
    await launch(tester);
    expect(find.text('내 여행'), findsOneWidget);
    await tester.tap(find.text('도쿄 여행'));
    await tester.pumpAndSettle();
    expect(find.byType(TripHomeScreen), findsOneWidget);
    // 1,200엔 × 기록 당시 환율 9.5
    expect(find.text('11,400원'), findsWidgets);
    expect(find.text('이치란 라멘'), findsOneWidget);

    await tester.tap(find.text('장부 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsOneWidget);
    expect(find.text('이치란 라멘'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로가기').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('지출 기록').first);
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '500');
    await tester.ensureVisible(find.byKey(const ValueKey('expense-place')));
    await tester.enterText(find.byKey(const ValueKey('expense-place')), '편의점');
    await tester.pumpAndSettle();
    final card = find.widgetWithText(ChoiceChip, '카드');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장').last);
    await tester.pumpAndSettle();

    final added = firestore.documents.entries.singleWhere(
      (e) => e.key.contains('/expenses/') && e.value['place'] == '편의점',
    );
    expect(added.key, startsWith('$trips/tokyo/expenses/'));
    expect(added.value['amount'], 500);
    expect(added.value['rate'], 10); // 저장 시점의 팀 환율
    expect(find.byType(ExpenseFormScreen), findsNothing);
    // 11,400 + 500엔 × 10
    expect(find.text('16,400원'), findsWidgets);
    await close(tester);
  });

  testWidgets('여행 편집과 삭제가 TripApi에 반영된다', (tester) async {
    seedTrip('tokyo');
    await launch(tester);
    await tester.longPress(find.text('도쿄 여행'));
    await tester.pumpAndSettle();
    expect(find.text('여행 편집'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '오사카 여행');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(firestore.documents['$trips/tokyo']!['name'], '오사카 여행');
    expect(find.text('오사카 여행'), findsOneWidget);

    await tester.longPress(find.text('오사카 여행'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('여행 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(firestore.documents, isEmpty);
    expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
    await close(tester);
  });

  testWidgets('여행 중이면 그 여행 홈을 한 번만 자동으로 연다', (tester) async {
    seedTrip('ongoing', name: '방콕 여행', startIn: -1, endIn: 2);
    await launch(tester);
    expect(find.byType(TripHomeScreen), findsOneWidget);
    expect(find.textContaining('방콕 여행'), findsWidgets);
    await tester.tap(find.byTooltip('뒤로가기').last);
    await tester.pumpAndSettle();
    expect(find.byType(TripHomeScreen), findsNothing);
    expect(find.byType(TripListScreen), findsOneWidget);
    await close(tester);
  });

  test('TripListStore는 목록 순서를 따르고 지운 여행의 구독을 정리한다', () async {
    final source = StreamController<List<api.Trip>>();
    final made = <String, TripStore>{};
    api.Trip trip(String id) => api.Trip(
      id: id,
      name: id,
      budget: 1,
      currency: 'JPY',
      start: DateTime(2026),
      end: DateTime(2026, 1, 2),
    );
    var subscriptions = 0;
    final store = TripListStore(
      watchTrips: () {
        subscriptions++;
        return source.stream;
      },
      storeFor: (id) => made[id] = TripStore(
        tripId: id,
        tripStream: Stream.value(trip(id)),
        expenseStream: Stream.value(const []),
      ),
    );
    expect(store.isLoading, isTrue);
    source.add([trip('b'), trip('a')]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(store.isLoading, isFalse);
    expect([for (final t in store.trips) t.id], ['b', 'a']);

    source.add([trip('a')]);
    await Future<void>.delayed(Duration.zero);
    expect([for (final t in store.trips) t.id], ['a']);
    // 지운 여행의 스토어는 닫혀서 더는 저장하지 못한다.
    await expectLater(made['b']!.remove(), throwsA(isA<api.ApiException>()));

    source.addError(const api.ApiException('권한 없음'));
    await Future<void>.delayed(Duration.zero);
    expect(store.error, isA<api.ApiException>());
    expect(store.isLoading, isFalse);
    store.dispose();
    expect(subscriptions, 1);
    await source.close();
  });
}
