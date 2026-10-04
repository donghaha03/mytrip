import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/app.dart';
import 'package:tripapp/trip_home/screens/add_trip_screen.dart';
import 'package:tripapp/trip_home/screens/more_screen.dart';
import 'package:tripapp/trip_home/screens/trip_list_screen.dart';
import 'package:tripapp/trip_home/screens/trip_home_screen.dart';
import 'package:tripapp/trip_home/screens/ledger_screen.dart';
import 'package:tripapp/trip_home/screens/expense_form_screen.dart';
import 'package:tripapp/trip_home/screens/spending_overview_screen.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/services/backend.dart';
import 'package:tripapp/api/api.dart';
import 'package:tripapp/trip_home/theme/app_theme.dart';
import 'package:tripapp/trip_home/widgets/country_chip.dart';
import 'package:tripapp/trip_home/widgets/sheets.dart';
import 'package:tripapp/trip_home/widgets/quick_converter.dart';
import 'package:tripapp/trip_home/widgets/recent_expenses_card.dart';
import 'package:tripapp/trip_home/widgets/today_budget_sheet.dart';
import 'package:tripapp/trip_home/widgets/won_input_formatter.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildAppTheme(), home: child);

Future<void> _loadRates({double? yenRate}) async {
  final fetched = DateTime.now().toUtc();
  final client = MockClient(
    (_) async => http.Response(
      jsonEncode({
        'result': 'success',
        'base_code': 'KRW',
        'rate_date': fetched.toIso8601String().substring(0, 10),
        'fetched_at': fetched.toIso8601String(),
        'rates': {
          for (final c in [...kPrimaryCountries, ...kMoreCountries])
            c.currency: c.currency == 'JPY' && yenRate != null
                ? 1 / yenRate
                : c.unitAmount / c.krwPerUnit,
        },
      }),
      200,
    ),
  );
  try {
    await RateApi.load(force: true, client: client);
  } finally {
    client.close();
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadRates();
  });

  // 목업 스크린샷과 같은 폰 사이즈로 맞춘다 (iPhone 14 기준).
  setUp(() {
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

  test('기본 실행은 DB 연결 없는 화면 미리보기', () async {
    expect(await Backend.init(), BackendMode.local);
  });

  testWidgets('00 빈 화면이 그려진다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.text('첫 여행을 추가해 보세요'), findsOneWidget);
    expect(find.text('여행 일정과 지출을 한곳에서 관리해요'), findsOneWidget);
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

  testWidgets('04 국가 더보기 시트', (tester) async {
    await tester.pumpWidget(_wrap(const AddTripScreen()));
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('국가 더보기'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('country-search')),
      'Singapore',
    );
    await tester.pump();
    await tester.tap(find.text('싱가포르'));
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
    expect(find.text('시작일과 종료일을 선택해주세요'), findsOneWidget);

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

    await tester.enterText(find.byType(TextField).first, '방콕 여행'); // 이름 칸
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('방콕 여행'), findsOneWidget);
    expect(find.text('가족 여행'), findsNothing);
  });

  // ── 여행 홈 (01 에서 여행을 누르면) ─────────────────────────────
  // 홈은 요약 화면이며, 전체 장부·지출 입력은 별도로 연결한다.

  testWidgets('여행 홈: 사용한 금액과 예산이 메인', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();

    expect(find.byType(TripHomeScreen), findsOneWidget);
    expect(find.text('🇯🇵 일본 여행'), findsOneWidget); // 상단바
    expect(find.text('D-11'), findsOneWidget); // 목업: 오늘 + 11일 출발
    expect(find.textContaining('4박 5일'), findsOneWidget);

    // 목업 지출 ¥1,200 + ¥3,500 + ¥2,800 + ¥40,600 = ¥48,100 -> 456,950원
    expect(find.text('사용한 금액'), findsOneWidget);
    expect(find.text('456,950원'), findsOneWidget);
    expect(find.text('¥48,100'), findsOneWidget);
    expect(find.text('38%'), findsOneWidget);
    expect(find.text('1,200,000원'), findsOneWidget);
    expect(find.text('하루 240,000원'), findsOneWidget); // 1,200,000 / 5일
    expect(find.text('남은 금액'), findsOneWidget);
    expect(find.text('743,050원'), findsOneWidget);

    // 최근 3건 요약은 여기 있고(아래 최근 지출 카드 테스트 참고),
    // 전체 목록과 기록 입력은 장부 몫이다
    expect(find.text('이치란 라멘'), findsOneWidget);
    expect(find.text('신주쿠 호텔'), findsNothing); // 4번째라 요약에는 없다
  });

  testWidgets('여행 홈: 예산을 넘기면 "초과" 로 바뀐다', (tester) async {
    final trip = Trip(
      id: 'over',
      name: '과소비 여행',
      country: countryByCode('JPY')!,
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 2),
      budgetKrw: 10000,
      expenses: [
        Expense(
          id: 'x',
          icon: '🛍',
          place: '쇼핑',
          amount: 2000,
          date: DateTime(2026, 10, 1),
        ),
      ],
    );
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: trip)));
    // ¥2,000 = 19,000원, 예산 10,000원 -> 9,000원 초과
    expect(find.text('예산 초과'), findsOneWidget);
    expect(find.text('9,000원'), findsOneWidget);
    expect(find.text('190%'), findsOneWidget);
    expect(find.text('남은 금액'), findsNothing);
  });

  testWidgets('여행 홈: 하단에 장부로 가는 버튼들', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();

    expect(find.text('장부 보기'), findsOneWidget);
    expect(find.text('지출 기록'), findsOneWidget);

    await tester.tap(find.text('장부 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('신주쿠 호텔'), 200);
    await tester.pumpAndSettle();
    expect(find.text('신주쿠 호텔'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지출 기록'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('expense-amount')), findsOneWidget);
  });

  testWidgets('여행 홈: 오른쪽 위 ≡ 로 더보기에 들어가고 나온다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('mytrip 로그인'), findsNothing);
    expect(find.text('카드 연동'), findsNothing);
    expect(find.textContaining('담당'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TripHomeScreen), findsOneWidget);
  });

  testWidgets('여행 홈: 뒤로가기로 01 리스트에 돌아온다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('내 여행'), findsOneWidget);
  });

  testWidgets('여행 홈: 편집 시트에서 이름과 예산을 바꾼다', (tester) async {
    final thai = tripStore.trips.firstWhere((t) => t.id == 't3');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: thai)));

    await tester.tap(find.byTooltip('여행 편집'));
    await tester.pumpAndSettle();
    expect(find.text('여행 편집'), findsOneWidget);
    expect(find.text('여행 기간'), findsOneWidget);
    expect(find.text('1,800,000'), findsOneWidget); // 예산 칸이 현재 값으로 채워져 있다

    // 화면에 계산기 입력칸도 있어서 시트 안으로 좁힌다. 시트 안: [이름, 예산]
    final fields = find.descendant(
      of: find.byType(TripEditSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '치앙마이 여행');
    await tester.enterText(fields.at(1), '2000000');
    await tester.pump();
    expect(find.text('2,000,000'), findsOneWidget); // 예산 칸도 콤마

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('🇹🇭 치앙마이 여행'), findsOneWidget);
    // 지출이 없는 여행이라 예산과 남은 금액이 둘 다 2,000,000원
    expect(find.text('2,000,000원'), findsNWidgets(2));
    expect(tripStore.byId('t3')!.budgetKrw, 2000000);
  });

  testWidgets('여행 홈: 편집 시트에서 기간 칸을 누르면 05 달력이 뜬다', (tester) async {
    final thai = tripStore.trips.firstWhere((t) => t.id == 't3');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: thai)));
    await tester.tap(find.byTooltip('여행 편집'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();
    expect(find.text('여행 기간 선택'), findsOneWidget);
    // 현재 기간이 선택된 채로 열린다 (5박 6일)
    expect(find.text('5박 6일'), findsWidgets);
  });

  testWidgets('편집 결과가 기간까지 반영된다', (tester) async {
    tripStore.update(
      't3',
      start: DateTime(2027, 1, 10),
      end: DateTime(2027, 1, 12),
      budgetKrw: 300000,
    );
    final t = tripStore.byId('t3')!;
    expect(t.durationLabel, '2박 3일');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: t)));
    expect(find.textContaining('01.10 – 01.12'), findsOneWidget);
    expect(find.text('하루 100,000원'), findsOneWidget);
  });

  testWidgets('여행 홈: 여행 이름 옆 환율 + ⓘ 툴팁 (07)', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: japan)));
    expect(find.text('¥100 = ₩950'), findsOneWidget);

    await tester.tap(find.text('i'));
    await tester.pumpAndSettle();
    expect(find.text('환율 정보'), findsOneWidget);
    expect(find.textContaining('환율 기준일: '), findsOneWidget);
    expect(find.textContaining('마지막 수집: '), findsOneWidget);
    expect(find.text('자동 갱신: 매일 오전 6시(한국 시간)'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsNothing);
    expect(find.textContaining('최근 갱신: '), findsNothing);

    // 바깥을 누르면 닫힌다
    await tester.tapAt(const Offset(200, 700));
    await tester.pumpAndSettle();
    expect(find.text('환율 정보'), findsNothing);
  });

  testWidgets('여행 홈: 오늘 예산 아이콘 -> 남은 예산 ÷ 남은 날', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: japan)));

    await tester.tap(find.byTooltip('오늘 예산'));
    await tester.pumpAndSettle();
    // 출발 전(D-11): 남은 743,050원 ÷ 5일 = 148,610원
    expect(find.text('하루 예산'), findsOneWidget);
    expect(find.text('하루 148,610원'), findsOneWidget);
    expect(find.text('남은 743,050원 ÷ 5일'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('하루 148,610원'), findsNothing);
  });

  group('todayBudget', () {
    Trip trip({int budget = 100000, List<Expense>? expenses}) => Trip(
      id: 'x',
      name: 'x',
      country: countryByCode('JPY')!, // ¥100 = ₩950
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 5), // 5일
      budgetKrw: budget,
      expenses: expenses,
    );
    Expense spend(double yen, DateTime at) =>
        Expense(id: '$yen$at', icon: '·', place: '·', amount: yen, date: at);

    test('출발 전: 전체 일수로 나눈다', () {
      final b = todayBudget(trip(), DateTime(2026, 9, 20));
      expect(b.phase, TodayPhase.beforeTrip);
      expect(b.daysLeft, 5);
      expect(b.allowanceKrw, 20000);
    });

    test('여행 중: 오늘 아침 기준으로 나누고, 오늘 쓴 만큼 뺀다', () {
      // 3일차. 1일차에 ¥2,000(19,000원), 오늘 ¥1,000(9,500원)
      final t = trip(
        expenses: [
          spend(2000, DateTime(2026, 10, 1, 12)),
          spend(1000, DateTime(2026, 10, 3, 9)),
        ],
      );
      final b = todayBudget(t, DateTime(2026, 10, 3, 18));
      expect(b.phase, TodayPhase.during);
      expect(b.daysLeft, 3); // 3·4·5일
      // 아침 기준 남은 돈 = 100,000 - 19,000 = 81,000 -> ÷3 = 27,000
      expect(b.allowanceKrw, 27000);
      expect(b.spentTodayKrw, 9500);
      expect(b.leftTodayKrw, 17500);
    });

    test('마지막 날은 남은 돈 전부', () {
      final b = todayBudget(trip(), DateTime(2026, 10, 5, 23));
      expect(b.daysLeft, 1);
      expect(b.allowanceKrw, 100000);
    });

    test('예산을 이미 다 썼으면 0', () {
      final t = trip(
        budget: 10000,
        expenses: [spend(2000, DateTime(2026, 10, 1))],
      );
      final b = todayBudget(t, DateTime(2026, 10, 2));
      expect(b.phase, TodayPhase.overBudget);
      expect(b.allowanceKrw, 0);
    });

    test('끝난 여행', () {
      final b = todayBudget(trip(), DateTime(2026, 10, 6));
      expect(b.phase, TodayPhase.finished);
    });
  });

  testWidgets('여행 홈: 이름이 최대 길이여도 안 넘친다', (tester) async {
    // 넘치면 RenderFlex overflow 로 이 테스트가 깨진다.
    tripStore.rename('t1', '가' * 20);
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('가' * 20));
    await tester.pumpAndSettle();
    expect(find.byType(TripHomeScreen), findsOneWidget);
    expect(find.text('여행 완료'), findsOneWidget); // 미국 여행은 이미 끝났다
  });

  testWidgets('여행 홈: 편집 시트에서 삭제하면 리스트로 돌아가고 사라진다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('가' * 20)); // 위 테스트에서 이름을 바꾼 미국 여행
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('여행 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('이 여행을 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.byType(TripHomeScreen), findsNothing);
    expect(find.text('내 여행'), findsOneWidget);
    expect(find.text('가' * 20), findsNothing);
    expect(tripStore.byId('t1'), isNull);
  });

  testWidgets('여행 홈: 최근 지출 카드 (7일 막대 + 마지막 3건)', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: japan)));

    expect(find.text('최근 지출'), findsOneWidget);
    expect(find.text('4건'), findsOneWidget);
    expect(find.text('지출보기'), findsOneWidget);

    // 최신 3건만 (신주쿠 호텔은 4번째라 안 보인다)
    expect(find.text('이치란 라멘'), findsOneWidget);
    expect(find.text('JR 패스'), findsOneWidget);
    expect(find.text('돈키호테'), findsOneWidget);
    expect(find.text('신주쿠 호텔'), findsNothing);
    expect(find.text('11,400원'), findsWidgets); // ¥1,200
    expect(find.text('¥1,200 JPY'), findsOneWidget);

    await tester.tap(find.text('지출보기'));
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsOneWidget);
    expect(find.byType(SpendingOverviewScreen), findsNothing);
    await tester.scrollUntilVisible(find.text('신주쿠 호텔'), 200);
    await tester.pumpAndSettle();
    expect(find.text('신주쿠 호텔'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('한눈에 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(SpendingOverviewScreen), findsOneWidget);
  });

  testWidgets('여행 홈: 지출이 없으면 첫 기록을 권한다', (tester) async {
    final thai = tripStore.trips.firstWhere((t) => t.id == 't3');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: thai)));

    expect(find.text('아직 기록한 지출이 없어요'), findsOneWidget);
    await tester.tap(find.text('첫 지출 기록하기'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
  });

  test('dailySpending: 오늘까지 7일치로 묶는다', () {
    final now = DateTime(2026, 10, 10, 15);
    final t = Trip(
      id: 'd',
      name: 'd',
      country: countryByCode('JPY')!, // ¥100 = ₩950
      start: DateTime(2026, 10, 5),
      end: DateTime(2026, 10, 12),
      budgetKrw: 100000,
      expenses: [
        // 오늘 두 건 -> 합쳐진다
        Expense(
          id: '1',
          icon: '·',
          place: 'a',
          amount: 1000,
          date: DateTime(2026, 10, 10, 9),
        ),
        Expense(
          id: '2',
          icon: '·',
          place: 'b',
          amount: 2000,
          date: DateTime(2026, 10, 10, 20),
        ),
        // 6일 전 (구간 맨 앞)
        Expense(
          id: '3',
          icon: '·',
          place: 'c',
          amount: 500,
          date: DateTime(2026, 10, 4, 12),
        ),
        // 7일 전 -> 구간 밖이라 빠진다
        Expense(
          id: '4',
          icon: '·',
          place: 'd',
          amount: 9999,
          date: DateTime(2026, 10, 3),
        ),
      ],
    );

    final days = dailySpending(t, now);
    expect(days.length, 7);
    expect(days.first.day, DateTime(2026, 10, 4));
    expect(days.last.day, DateTime(2026, 10, 10));
    expect(days.first.krw, 4750); // ¥500
    expect(days.last.krw, 28500); // ¥3,000
    expect(days[3].krw, 0); // 아무것도 안 쓴 날
  });

  group('빠른 환산', () {
    Widget converter(String code) =>
        _wrap(Scaffold(body: QuickConverter(country: countryByCode(code)!)));

    testWidgets('환율이 없으면 계산을 비활성화한다', (tester) async {
      RateApi.reset();
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => _loadRates());
      await tester.pumpWidget(
        _wrap(Scaffold(body: QuickConverter(country: countryByCode('JPY')!))),
      );
      expect(find.text('환율 없음'), findsOneWidget);
      expect(find.text('소수점은 버려요'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('엔 -> 원', (tester) async {
      await tester.pumpWidget(converter('JPY'));
      expect(find.text('¥'), findsOneWidget); // 빈 칸이어도 통화 기호는 보인다

      await tester.enterText(find.byType(TextField), '1500');
      await tester.pump();
      expect(find.text('1,500'), findsOneWidget); // 입력칸도 콤마
      expect(find.text('14,250원'), findsOneWidget);
    });

    testWidgets('방향을 바꾸면 지금 결과가 새 입력이 된다', (tester) async {
      await tester.pumpWidget(converter('JPY'));
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();

      await tester.tap(find.byTooltip('방향 바꾸기'));
      await tester.pump();
      expect(find.text('KRW → JPY'), findsOneWidget);
      expect(find.text('9,500'), findsOneWidget); // 입력칸
      expect(find.text('¥1,000'), findsOneWidget); // 결과
    });

    testWidgets('달러도 소수점을 버리고 정수만 환산한다', (tester) async {
      await tester.pumpWidget(converter('USD'));
      await tester.enterText(find.byType(TextField), '12.5');
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
      expect(find.text('16,200원'), findsOneWidget); // 12 * 1,350

      await tester.tap(find.byTooltip('방향 바꾸기'));
      await tester.pump();
      expect(find.text('\$12'), findsOneWidget);
    });

    testWidgets('API 소수 환율 갱신을 양방향 환산에 즉시 반영한다', (tester) async {
      addTearDown(() => _loadRates());
      await tester.pumpWidget(converter('JPY'));
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();
      expect(find.text('9,500원'), findsOneWidget);

      await tester.runAsync(() => _loadRates(yenRate: 8.624175011418408));
      await tester.pump();
      expect(find.text('8,620원'), findsOneWidget);
      expect(find.text('1,000'), findsOneWidget); // 갱신해도 입력은 유지한다.
      expect(find.text('9,500원'), findsNothing);

      await tester.tap(find.byTooltip('방향 바꾸기'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '456950');
      await tester.pump();
      expect(find.text('KRW → JPY'), findsOneWidget);
      expect(find.text('¥53,010'), findsOneWidget);
    });

    test('원 -> 현지 통화 변환', () {
      expect(countryByCode('USD')!.formatForeign(7.4074), '\$7');
      expect(countryByCode('VND')!.formatForeign(12345.6), '₫12,345');
    });
  });

  group('AmountInputFormatter (소수점)', () {
    const f = AmountInputFormatter(decimals: 2);
    String type(String t) => f
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: t.length),
          ),
        )
        .text;

    test('정수부만 콤마, 소수부는 그대로', () {
      expect(type('1234.56'), '1,234.56');
      expect(type('1234.'), '1,234.');
    });

    test('소수점부터 치면 0 을 붙인다', () {
      expect(type('.5'), '0.5');
    });

    test('소수점은 하나만, 자릿수는 decimals 까지', () {
      expect(type('1.2.3'), '1.23');
      final v = f.formatEditUpdate(
        const TextEditingValue(text: '1.23'),
        const TextEditingValue(text: '1.234'),
      );
      expect(v.text, '1.23');
    });

    test('decimals 0 이면 소수점을 버린다 (원화 예산)', () {
      const won = WonInputFormatter();
      expect(
        won
            .formatEditUpdate(
              TextEditingValue.empty,
              const TextEditingValue(text: '12.5'),
            )
            .text,
        '12',
      );
    });
  });

  group('여행 중이면 메인 페이지부터', () {
    Trip ongoing(String id, {required DateTime start, required DateTime end}) =>
        Trip(
          id: id,
          name: '진행중 $id',
          country: countryByCode('JPY')!,
          start: start,
          end: end,
          budgetKrw: 500000,
        );

    test('오늘이 기간 안이면 그 여행 (시작·종료일 포함)', () {
      final now = DateTime(2026, 10, 3, 14);
      final t = ongoing(
        'a',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 5),
      );
      expect(ongoingTrip([t], now)?.id, 'a');
      // 시작일 당일 / 종료일 당일도 "여행 중"
      expect(ongoingTrip([t], DateTime(2026, 10, 1, 0, 5))?.id, 'a');
      expect(ongoingTrip([t], DateTime(2026, 10, 5, 23, 55))?.id, 'a');
    });

    test('기간 밖이면 null', () {
      final t = ongoing(
        'a',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 5),
      );
      expect(ongoingTrip([t], DateTime(2026, 9, 30, 23)), isNull);
      expect(ongoingTrip([t], DateTime(2026, 10, 6)), isNull);
      expect(ongoingTrip([], DateTime(2026, 10, 3)), isNull);
    });

    test('겹치면 먼저 시작한 여행', () {
      final a = ongoing(
        'a',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 9),
      );
      final b = ongoing(
        'b',
        start: DateTime(2026, 10, 2),
        end: DateTime(2026, 10, 4),
      );
      expect(ongoingTrip([b, a], DateTime(2026, 10, 3))?.id, 'a');
    });

    testWidgets('앱을 켜면 여행 목록 대신 메인 페이지, 뒤로가기로 목록', (tester) async {
      final now = DateTime.now();
      tripStore.add(
        ongoing(
          'now',
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 1)),
        ),
      );
      addTearDown(() => tripStore.remove('now'));

      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();

      // 목록을 건너뛰고 그 여행 화면이 바로 떠 있다
      expect(find.byType(TripHomeScreen), findsOneWidget);
      expect(find.text('🇯🇵 진행중 now'), findsOneWidget);
      expect(find.text('내 여행'), findsNothing);

      // 좌측 상단 뒤로가기 -> 여행 선택(목록)
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('내 여행'), findsOneWidget);
      expect(find.byType(TripHomeScreen), findsNothing);
    });

    testWidgets('여행 중이 아니면 평소대로 목록부터', (tester) async {
      // 목업 3건은 모두 오늘이 기간 밖이다
      await tester.pumpWidget(const TripApp());
      await tester.pumpAndSettle();
      expect(find.text('내 여행'), findsOneWidget);
      expect(find.byType(TripHomeScreen), findsNothing);
    });
  });

  group('tripStatusLabel', () {
    final trip = Trip(
      id: 'x',
      name: 'x',
      country: kPrimaryCountries.first,
      start: DateTime(2026, 10, 1, 9, 30),
      end: DateTime(2026, 10, 5),
      budgetKrw: 0,
    );

    test('출발 전은 D-day', () {
      expect(tripStatusLabel(trip, DateTime(2026, 9, 20, 23, 59)), 'D-11');
      expect(tripStatusLabel(trip, DateTime(2026, 9, 30)), 'D-1');
    });

    test('여행 중은 며칠째인지 (시각은 무시)', () {
      expect(tripStatusLabel(trip, DateTime(2026, 10, 1, 0, 1)), '여행 중 · 1일차');
      expect(tripStatusLabel(trip, DateTime(2026, 10, 5, 23, 0)), '여행 중 · 5일차');
    });

    test('끝난 뒤는 여행 완료', () {
      expect(tripStatusLabel(trip, DateTime(2026, 10, 6)), '여행 완료');
    });
  });

  testWidgets('데스크톱 폭에서도 폰 폭으로 묶인다', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(2580, 2000); // 1290x1000 @2x
    view.devicePixelRatio = 2.0;

    await tester.pumpWidget(const TripApp());
    // 화면이 아무리 넓어도 본문은 kPhoneWidth 를 넘지 않는다
    final body = tester.getSize(find.byType(Scaffold).first);
    expect(body.width, lessThanOrEqualTo(kPhoneWidth));

    // 02 국가 그리드 칸은 폭과 무관하게 높이가 고정
    await tester.tap(find.text('여행 추가하기'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CountryChip).first).height,
      kCountryChipHeight,
    );

    // 04 더보기 시트도 같은 칸 높이 (overflow 나면 여기서 깨진다)
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    expect(find.text('국가 더보기'), findsOneWidget);
    expect(find.byKey(const ValueKey('country-list')), findsOneWidget);
    expect(
      tester.getSize(find.byType(MoreCountrySheet)).width,
      lessThanOrEqualTo(kPhoneWidth),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('02 예산 입력에 콤마가 즉시 찍힌다', (tester) async {
    await tester.pumpWidget(_wrap(const AddTripScreen()));
    final field = find.widgetWithText(TextField, '1,200,000'); // hint
    await tester.enterText(field, '1200000');
    await tester.pump();
    expect(find.text('1,200,000'), findsWidgets);

    // 콤마가 붙어도 여행 생성 시 숫자로 되읽을 수 있어야 한다
    await tester.enterText(field, '850000');
    await tester.pump();
    expect(find.text('850,000'), findsOneWidget);
  });

  group('WonInputFormatter', () {
    const f = WonInputFormatter();

    TextEditingValue type(String text, {int? caret}) => f.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: caret ?? text.length),
      ),
    );

    test('천 단위마다 콤마', () {
      expect(type('1200000').text, '1,200,000');
      expect(type('999').text, '999');
      expect(type('1000').text, '1,000');
      expect(type('').text, '');
    });

    test('숫자가 아닌 입력은 걸러낸다', () {
      expect(type('12a3!4').text, '1,234');
    });

    test('선행 0 제거', () {
      expect(type('007').text, '7');
      expect(type('0').text, '0');
    });

    test('커서가 맨 뒤로 튀지 않는다', () {
      // "1,234,567" 에서 맨 앞 '1' 뒤(숫자 1개 지난 지점)에 커서
      final v = type('1234567', caret: 1);
      expect(v.text, '1,234,567');
      expect(v.selection.baseOffset, 1);

      // 숫자 4개 지난 지점 -> "1,234|,567"
      final v2 = type('1234567', caret: 4);
      expect(v2.text, '1,234,567');
      expect(v2.text.substring(0, v2.selection.baseOffset), '1,234');
    });

    test('자릿수 상한을 넘기면 입력을 무시', () {
      const old = TextEditingValue(text: '999,999,999,999');
      final v = f.formatEditUpdate(
        old,
        const TextEditingValue(text: '9999999999999'), // 13자리
      );
      expect(v.text, old.text);
    });
  });

  test('환율 환산 / 포맷', () {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    // 100엔 = 950원 이므로 ¥1,200 -> 11,400원
    expect(RateApi.toKrw(1200, japan.country.currency), 11400);
    expect(currentRateLabel(japan.country), '¥100 = ₩950');
    expect(currentRateLabel(countryByCode('USD')!), '\$1 = ₩1,350');
    expect(formatWon(742300), '742,300원');
    expect(formatNumber(-1234567), '-1,234,567');
  });

  testWidgets('상단·사용액·남은액·빠른 환산·오늘 예산이 정수 환율로 일치한다', (tester) async {
    final japan = tripStore.byId('t2')!;
    addTearDown(() => _loadRates());
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: japan)));
    await tester.runAsync(() => _loadRates(yenRate: 8.624175011418408));
    await tester.pump();
    expect(find.text('¥100 = ₩862'), findsOneWidget);
    expect(find.textContaining('적용 환율:'), findsNothing);
    expect(find.text('소수점은 버려요'), findsNothing);
    expect(find.text('상단 정수 환율 기준 · 소수점 버림'), findsNothing);
    expect(find.text('샘플 지출 · 고정 환율 기준'), findsNothing);
    expect(japan.spentKrw, 414622);
    expect(japan.remainKrw, 785378);
    expect(find.text('414,622원'), findsOneWidget);
    expect(find.text('¥48,100'), findsOneWidget);
    expect(find.text('785,378원'), findsOneWidget);
    expect(find.text('¥91,111'), findsOneWidget);
    expect(find.text('10,344원'), findsWidgets); // 최근 지출도 1200 * 862 ~/ 100.
    final input = find.descendant(
      of: find.byType(QuickConverter),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, '1000');
    await tester.pump();
    expect(find.text('8,620원'), findsOneWidget);
    await tester.tap(find.byTooltip('방향 바꾸기'));
    await tester.pump();
    for (final pair in [(414622, '¥48,100'), (785378, '¥91,111')]) {
      await tester.enterText(input, '${pair.$1}');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(QuickConverter),
          matching: find.text(pair.$2),
        ),
        findsOneWidget,
      );
    }
    await tester.ensureVisible(find.byTooltip('오늘 예산'));
    await tester.tap(find.byTooltip('오늘 예산'));
    await tester.pumpAndSettle();
    expect(find.text('하루 157,075원'), findsOneWidget); // 785378 ~/ 5.
    expect(find.text('¥18,222'), findsOneWidget);
    expect(find.textContaining('환율 제공:'), findsNothing);
  });

  testWidgets('1엔 미만 버림도 사용액의 원→엔과 빠른 환산에 동일하다', (tester) async {
    addTearDown(() => _loadRates());
    await tester.runAsync(() => _loadRates(yenRate: 8.624175011418408));
    final trip = Trip(
      id: 'integer',
      name: '정수 여행',
      country: countryByCode('JPY')!,
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 2),
      budgetKrw: 1000,
      expenses: [
        Expense(
          id: '1',
          icon: '·',
          place: '소액',
          amount: 51.9,
          date: DateTime(2026, 10, 1),
        ),
      ],
    );
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: trip)));
    expect(trip.spentKrw, 439);
    expect(find.text('¥50'), findsOneWidget); // 439 * 100 ~/ 862, 기록 원본 51과 구분.
    final input = find.descendant(
      of: find.byType(QuickConverter),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(input);
    await tester.tap(find.byTooltip('방향 바꾸기'));
    await tester.pump();
    await tester.enterText(input, '439.9');
    await tester.pump();
    expect(find.text('439'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(QuickConverter),
        matching: find.text('¥50'),
      ),
      findsOneWidget,
    );
  });
}
