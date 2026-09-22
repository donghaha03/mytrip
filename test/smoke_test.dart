import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripapp/data/trip_store.dart';
import 'package:tripapp/main.dart';
import 'package:tripapp/screens/add_trip_screen.dart';
import 'package:tripapp/screens/more_screen.dart';
import 'package:tripapp/screens/trip_list_screen.dart';
import 'package:tripapp/screens/trip_home_screen.dart';
import 'package:tripapp/models/country.dart';
import 'package:tripapp/models/trip.dart';
import 'package:tripapp/theme/app_theme.dart';
import 'package:tripapp/widgets/country_chip.dart';
import 'package:tripapp/widgets/sheets.dart';
import 'package:tripapp/widgets/quick_converter.dart';
import 'package:tripapp/widgets/won_input_formatter.dart';

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

  // ── 여행 홈 (01 에서 여행을 누르면) ─────────────────────────────
  // 03 메인(남은 예산·지출 목록)과 07 환율 툴팁은 장부 담당 몫이라 여기 없다.

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

    // 지출 목록은 장부 몫이라 없다
    expect(find.text('이치란 라멘'), findsNothing);
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
            id: 'x', icon: '🛍', place: '쇼핑', amount: 2000, date: DateTime(2026, 10, 1)),
      ],
    );
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: trip)));
    // ¥2,000 = 19,000원, 예산 10,000원 -> 9,000원 초과
    expect(find.text('초과'), findsOneWidget);
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

    // 장부가 아직 없으니 두 버튼 다 안내만 띄우고 화면은 그대로
    await tester.tap(find.text('장부 보기'));
    await tester.pump();
    expect(find.text('장부 페이지는 준비 중이에요'), findsOneWidget);

    await tester.tap(find.text('지출 기록'));
    await tester.pump();
    expect(find.text('지출 기록은 장부 페이지에서 할 수 있어요 (준비 중)'),
        findsOneWidget);
    expect(find.byType(TripHomeScreen), findsOneWidget);
  });

  testWidgets('여행 홈: 오른쪽 위 ≡ 로 더보기에 들어가고 나온다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('더보기'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);

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

  testWidgets('여행 홈: 편집 버튼으로 06 시트를 열어 이름을 바꾼다', (tester) async {
    final thai = tripStore.trips.firstWhere((t) => t.id == 't3');
    await tester.pumpWidget(_wrap(TripHomeScreen(trip: thai)));

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('여행 편집'), findsOneWidget);

    // 화면에 계산기 입력칸도 있어서 시트 안의 입력칸으로 좁힌다
    await tester.enterText(
      find.descendant(
          of: find.byType(TripEditSheet), matching: find.byType(TextField)),
      '치앙마이 여행',
    );
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('🇹🇭 치앙마이 여행'), findsOneWidget);
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

    expect(find.byType(TripHomeScreen), findsNothing);
    expect(find.text('내 여행'), findsOneWidget);
    expect(find.text('가' * 20), findsNothing);
    expect(tripStore.byId('t1'), isNull);
  });

  group('빠른 환산', () {
    Widget converter(String code) =>
        _wrap(Scaffold(body: QuickConverter(country: countryByCode(code)!)));

    testWidgets('엔 -> 원, 빠른 금액 칩', (tester) async {
      await tester.pumpWidget(converter('JPY'));
      expect(find.text('¥100 = ₩950 기준'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1500');
      await tester.pump();
      expect(find.text('1,500'), findsOneWidget); // 입력칸도 콤마
      expect(find.text('14,250원'), findsOneWidget);

      await tester.tap(find.text('¥1,000'));
      await tester.pump();
      expect(find.text('9,500원'), findsOneWidget);
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

    testWidgets('달러는 센트까지', (tester) async {
      await tester.pumpWidget(converter('USD'));
      await tester.enterText(find.byType(TextField), '12.5');
      await tester.pump();
      expect(find.text('16,875원'), findsOneWidget); // 12.5 * 1,350

      await tester.tap(find.byTooltip('방향 바꾸기'));
      await tester.pump();
      expect(find.text('\$12.50'), findsOneWidget);
    });

    test('원 -> 현지 통화 변환', () {
      expect(krwToForeign(countryByCode('JPY')!, 9500), closeTo(1000, 1e-9));
      expect(formatForeignAmount(countryByCode('USD')!, 7.4074), '\$7.41');
      expect(formatForeignAmount(countryByCode('VND')!, 12345.6), '₫12,346');
    });
  });

  group('AmountInputFormatter (소수점)', () {
    const f = AmountInputFormatter(decimals: 2);
    String type(String t) => f
        .formatEditUpdate(TextEditingValue.empty,
            TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length)))
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
        won.formatEditUpdate(TextEditingValue.empty,
            const TextEditingValue(text: '12.5')).text,
        '125',
      );
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
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(2580, 2000); // 1290x1000 @2x
    view.devicePixelRatio = 2.0;

    await tester.pumpWidget(const TripApp());
    // 화면이 아무리 넓어도 본문은 kPhoneWidth 를 넘지 않는다
    final body = tester.getSize(find.byType(Scaffold).first);
    expect(body.width, lessThanOrEqualTo(kPhoneWidth));

    // 02 국가 그리드 칸은 폭과 무관하게 높이가 고정
    await tester.tap(find.text('여행 선택하기'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(CountryChip).first).height,
      kCountryChipHeight,
    );

    // 04 더보기 시트도 같은 칸 높이 (overflow 나면 여기서 깨진다)
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    expect(find.text('국가 더보기'), findsOneWidget);
    final sheetChips = find.descendant(
      of: find.byType(MoreCountrySheet),
      matching: find.byType(CountryChip),
    );
    expect(sheetChips, findsNWidgets(kMoreCountries.length));
    expect(tester.getSize(sheetChips.first).height, kCountryChipHeight);
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
            selection:
                TextSelection.collapsed(offset: caret ?? text.length),
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
    expect(japan.country.toKrw(1200), 11400);
    expect(japan.country.rateLabel, '¥100 = ₩950');
    expect(
      kPrimaryCountries.firstWhere((c) => c.currency == 'USD').rateLabel,
      '\$1 = ₩1,350',
    );
    expect(formatWon(742300), '742,300원');
    expect(formatNumber(-1234567), '-1,234,567');
  });
}
