import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart' as api;
import 'package:tripapp/ledger/card_message/card_drafts.dart';
import 'package:tripapp/ledger/card_message/card_message_parser.dart';
import 'package:tripapp/ledger/data/trip_store.dart';
import 'package:tripapp/ledger/models/country.dart';
import 'package:tripapp/ledger/models/trip.dart' as ledger;
import 'package:tripapp/ledger/screens/ledger_screen.dart';
import 'package:tripapp/ledger/theme/app_theme.dart';

import 'fixtures/card_message_samples.dart';

/// 알림을 받은 시각(연도 기준).
final now = DateTime(2026, 10, 8, 9);

ParsedCardPayment parse(String text, {String title = ''}) =>
    parseCardMessage(text, title: title, now: now)!;

api.Expense saved({
  String id = 'e1',
  String place = '스타벅스',
  double amount = 12300,
  DateTime? date,
  api.ExpenseStatus status = api.ExpenseStatus.approved,
}) => api.Expense(
  id: id,
  category: '식비',
  place: place,
  amount: amount,
  currency: 'KRW',
  rate: 1,
  date: date ?? DateTime(2026, 10, 4, 14, 32),
  status: status,
);

class RecordingStore extends TripStore {
  RecordingStore()
    : super(
        tripId: 'test',
        tripStream: Stream.value(
          api.Trip(
            id: 'test',
            name: '도쿄 여행',
            budget: 100000,
            currency: 'JPY',
            start: DateTime(2026, 10, 1),
            end: DateTime(2026, 10, 7),
          ),
        ),
        expenseStream: Stream.value(const []),
      );
  api.Expense? saved;
  @override
  Future<void> saveExpense(String id, api.Expense value) async {
    saved = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('파서', () {
    test('카드사 9곳의 승인 문자에서 가맹점·금액을 읽는다', () {
      expect(issuerSamples.map((s) => s.$1).toSet().length, 9);
      for (final (issuer, text, merchant, amount) in issuerSamples) {
        final p = parse(text);
        expect(p.issuer, issuer, reason: text);
        expect(p.merchant, merchant, reason: text);
        expect(p.amount, amount, reason: text);
        expect(p.currency, 'KRW', reason: text);
        expect(p.cancelled, isFalse, reason: text);
        expect((p.date.year, p.date.month), (2026, 10), reason: text);
      }
    });

    test('일시와 할부를 읽는다', () {
      final p = parse(shinhanApproval);
      expect(p.date, DateTime(2026, 10, 4, 14, 32));
      expect(p.installmentMonths, 0);
      expect(parse(hyundaiInstallment).installmentMonths, 3);
    });

    test('승인취소와 해외승인을 구분한다', () {
      final cancel = parse(shinhanCancel);
      expect(cancel.cancelled, isTrue);
      expect(cancel.merchant, '스타벅스');
      expect(cancel.amount, 12300);
      final overseas = parse(shinhanOverseas);
      expect(overseas.currency, 'USD');
      expect(overseas.amount, 12.30);
      expect(overseas.merchant, 'STARBUCKS TOKYO');
      expect(overseas.cancelled, isFalse);
    });

    test('알림톡의 항목 이름과 앱 푸시의 제목을 쓴다', () {
      final kakao = parse(kakaoApproval);
      expect(kakao.merchant, '스타벅스 강남점');
      expect(kakao.amount, 12300);
      final push = parse(pushText, title: pushTitle);
      expect(push.issuer, '신한');
      expect(push.merchant, '스타벅스');
      expect(push.amount, 12300);
    });

    test('이름·카드번호·누적금액은 결과에 넣지 않는다', () {
      for (final (_, text, _, _) in issuerSamples) {
        final json = jsonEncode(parse(text));
        for (final secret in ['홍', '동님', '1234', '1*', '누적', '잔액']) {
          expect(json.contains(secret), isFalse, reason: '$secret in $json');
        }
      }
    });

    test('카드 승인 알림이 아니면 null', () {
      for (final text in notCardMessages) {
        expect(parseCardMessage(text, now: now), isNull, reason: text);
      }
    });

    test('연도가 없는 연말 문자를 새해에 읽으면 작년으로 본다', () {
      final p = parseCardMessage(
        '신한카드(1234)승인 홍*동 5,000원(일시불)12/31 23:58 편의점',
        now: DateTime(2027, 1, 1, 0, 10),
      )!;
      expect(p.date, DateTime(2026, 12, 31, 23, 58));
    });

    test('대기 목록 저장 형식을 그대로 되읽는다', () {
      final p = parse(hyundaiInstallment);
      final back = ParsedCardPayment.fromJson(jsonDecode(jsonEncode(p)))!;
      expect(back.toJson(), p.toJson());
      expect(ParsedCardPayment.fromJson({'merchant': 1}), isNull);
    });
  });

  group('장부 연결', () {
    test('큐 안의 중복과 이미 저장된 지출을 걸러낸다', () {
      final sms = parse(shinhanApproval), kakao = parse(kakaoApproval);
      expect(dedupeCardPayments([sms, kakao], const []), [sms]);
      expect(dedupeCardPayments([sms], [saved()]), isEmpty);
      // 시각이 10분 다르면 다른 결제
      final later = saved(date: DateTime(2026, 10, 4, 14, 42));
      expect(dedupeCardPayments([sms], [later]), [sms]);
      expect(dedupeCardPayments([sms], [saved(amount: 9900)]), [sms]);
    });

    test('승인취소는 같은 금액·가맹점의 승인 지출을 찾아 제안만 한다', () {
      final cancel = parse(shinhanCancel);
      expect(findCancelTarget(cancel, [saved()])!.id, 'e1');
      expect(findCancelTarget(cancel, [saved(amount: 9900)]), isNull);
      expect(findCancelTarget(cancel, [saved(place: '이디야')]), isNull);
      // 취소보다 나중에 한 결제는 대상이 아니다
      final after = saved(date: DateTime(2026, 10, 5, 9));
      expect(findCancelTarget(cancel, [after]), isNull);
      // 취소 알림 자체는 지출이 취소 처리될 때까지 대기 목록에 남는다
      expect(dedupeCardPayments([cancel], [saved()]), [cancel]);
      final done = saved(status: api.ExpenseStatus.cancelled);
      expect(dedupeCardPayments([cancel], [done]), isEmpty);
      expect(findCancelTarget(cancel, [done]), isNull);
    });

    test('초안은 저장 규칙(사용처·금액·카테고리·통화)을 지킨다', () {
      for (final (_, text, _, _) in issuerSamples) {
        final draft = draftExpense(parse(text));
        expect(draft.id, isEmpty);
        expect(draft.place.trim(), isNotEmpty);
        expect(draft.amount, greaterThan(0));
        expect(draft.rate, 1);
        expect(api.categoryIcons.containsKey(draft.category), isTrue);
        expect(RegExp(r'^[A-Z]{3}$').hasMatch(draft.currency), isTrue);
        expect(draft.memo.length, lessThanOrEqualTo(300));
        expect(draft.source, cardNotificationSource);
        expect(draft.isImported, isTrue);
        expect(draft.paymentMethod, api.PaymentMethod.card);
        expect(draft.status, api.ExpenseStatus.approved);
      }
      expect(draftExpense(parse(hyundaiInstallment)).memo, contains('3개월'));
    });

    test('가맹점 이름으로 카테고리를 추정하고 모르면 기타', () {
      expect(guessCardCategory('스타벅스'), '식비');
      expect(guessCardCategory('카카오T택시'), '교통');
      expect(guessCardCategory('롯데호텔서울'), '숙박');
      expect(guessCardCategory('경복궁매표소'), '관광');
      expect(guessCardCategory('올리브영'), '쇼핑');
      expect(guessCardCategory('STARBUCKS TOKYO'), '식비');
      expect(guessCardCategory('홍길동상사'), '기타');
    });

    test('결제일이 여행 기간 밖이면 알린다', () {
      final trip = ledger.Trip(
        id: 't',
        name: '도쿄 여행',
        country: countryByCode('JPY')!,
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 7, 23),
        budgetKrw: 100000,
      );
      expect(outsideTrip(trip, DateTime(2026, 10, 1, 0, 1)), isFalse);
      expect(outsideTrip(trip, DateTime(2026, 10, 7, 23, 59)), isFalse);
      expect(outsideTrip(trip, DateTime(2026, 9, 30, 23, 59)), isTrue);
      expect(outsideTrip(trip, DateTime(2026, 10, 8)), isTrue);
    });
  });

  testWidgets('장부 화면에서 카드 알림을 확인하고 저장한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('tripapp/card_notifications');
    var drained = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'isEnabled') return true;
      if (call.method != 'drain' || drained) return <Object?>[];
      drained = true;
      return [
        {
          'title': '',
          'text': shinhanApproval,
          'postedAt': DateTime(2026, 10, 4, 14, 33).millisecondsSinceEpoch,
        },
      ];
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final store = RecordingStore();
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LedgerScreen(trip: store.trip!, store: store),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('새 카드 승인 1건'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('card-inbox-banner')));
    await tester.pumpAndSettle();
    expect(find.text('스타벅스'), findsOneWidget);
    expect(store.saved, isNull);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.saved!.place, '스타벅스');
    expect(store.saved!.amount, 12300);
    expect(store.saved!.currency, 'KRW');
    expect(store.saved!.date, DateTime(2026, 10, 4, 14, 32));
    expect(store.saved!.source, cardNotificationSource);
    expect(find.text('새 카드 승인 1건'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
