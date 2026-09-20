import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripapp/data/trip_store.dart';
import 'package:tripapp/main.dart';
import 'package:tripapp/screens/add_trip_screen.dart';
import 'package:tripapp/screens/ledger_screen.dart';
import 'package:tripapp/screens/more_screen.dart';
import 'package:tripapp/screens/trip_list_screen.dart';
import 'package:tripapp/screens/trip_main_screen.dart';
import 'package:tripapp/models/country.dart';
import 'package:tripapp/theme/app_theme.dart';
import 'package:tripapp/widgets/country_chip.dart';
import 'package:tripapp/widgets/sheets.dart';
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

  testWidgets('03 메인 페이지 예산 카드 + 최근 지출', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripMainScreen(trip: japan)));
    expect(find.text('남은 예산'), findsOneWidget);
    expect(find.text('¥100 = ₩950'), findsOneWidget);
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
    final trip = tripStore.trips.firstWhere((t) => t.id == 't1'); // $1 = ₩1,350
    tripStore.rename(trip.id, '가' * 20);
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('가' * 20));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('\$1 = ₩1,350'), findsOneWidget);
  });

  // 08/09 는 각자 담당자가 채운다. 아래 두 테스트는 "03 에서 진입할 수 있고
  // 뒤로 돌아온다" 는 연결만 확인한다 — 페이지 내용은 자유롭게 바꿔도 된다.
  testWidgets('08 장부 페이지로 들어가고 나온다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('📒  여행 장부 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('남은 예산'), findsOneWidget);
  });

  testWidgets('09 더보기 페이지로 들어가고 나온다', (tester) async {
    await tester.pumpWidget(const TripApp());
    await tester.tap(find.text('일본 여행'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('더보기'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('남은 예산'), findsOneWidget);
  });

  testWidgets('07 환율 정보 툴팁', (tester) async {
    final japan = tripStore.trips.firstWhere((t) => t.id == 't2');
    await tester.pumpWidget(_wrap(TripMainScreen(trip: japan)));

    await tester.tap(find.text('i'));
    await tester.pumpAndSettle();
    expect(find.text('환율 갱신 정보'), findsOneWidget);
    expect(find.text('환율은 24시간마다 한 번 갱신돼요'), findsOneWidget);
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
