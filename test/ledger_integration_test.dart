import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart' as api;
import 'package:tripapp/ledger/data/trip_store.dart';
import 'package:tripapp/ledger/models/spending_summary.dart';
import 'package:tripapp/ledger/screens/expense_form_screen.dart';
import 'package:tripapp/ledger/screens/ledger_screen.dart';
import 'package:tripapp/ledger/theme/app_theme.dart';

api.Trip trip(String id) => api.Trip(
  id: id,
  name: '도쿄 여행',
  budget: 100000,
  currency: 'JPY',
  start: DateTime(2026, 10, 1),
  end: DateTime(2026, 10, 7),
);

api.Expense expense({String id = 'receipt', double amount = 12.50}) =>
    api.Expense(
      id: id,
      category: '식비',
      place: '카페',
      amount: amount,
      currency: 'USD',
      rate: 1300.5,
      date: DateTime(2026, 10, 3, 12, 34),
      paymentMethod: api.PaymentMethod.card,
      isTaxFree: true,
      memo: '영수증 보관',
      receiptFingerprint: 'fixture',
      receiptItems: const [
        api.ReceiptItem(name: 'Coffee', quantity: 1, amount: 12.5),
      ],
      receiptTaxes: const [
        api.ReceiptTax(
          label: '부가세',
          amount: 1.5,
          currency: 'USD',
          included: true,
        ),
      ],
      receiptAdjustments: const api.ReceiptAdjustments(
        discount: 2,
        currency: 'USD',
      ),
    );

class RecordingStore extends TripStore {
  RecordingStore(List<api.Expense> entries)
    : super(
        tripId: 'test',
        tripStream: Stream.value(trip('test')),
        expenseStream: Stream.value(entries),
      );
  api.Expense? saved;
  bool failSave = false;
  @override
  String newExpenseId() => 'new-generated-id';
  @override
  Future<void> saveExpense(String id, api.Expense value) async {
    api.ExpenseApi.validate(value);
    if (failSave) throw const api.ApiException('저장 실패');
    saved = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'rates': jsonEncode({'JPY': 0.1, 'USD': 1 / 1500, 'KRW': 1}),
      'rates_time': DateTime.now().toIso8601String(),
    });
    await api.RateApi.load();
  });

  test('팀의 기존 지출 문서와 새 영수증 필드를 함께 읽고 보존한다', () {
    final original = expense();
    final restored = api.Expense.fromMap(original.id, original.toMap());
    expect(restored.toMap(), original.toMap());
    final edited = restored.copyWith(place: '수정한 카페');
    expect(edited.rate, original.rate);
    expect(edited.date, original.date);
    expect(edited.receiptItems.single.name, 'Coffee');
    expect(edited.receiptTaxes.single.amount, 1.5);
    expect(edited.receiptAdjustments!.discount, 2);
    expect(edited.memo, '영수증 보관');
    expect(edited.paymentMethod, api.PaymentMethod.card);
    final legacy = api.Expense.fromMap('old', {
      'place': '기존 식당',
      'category': '식비',
      'amount': 100,
      'currency': 'JPY',
      'rate': 9.5,
      'date': Timestamp.fromDate(DateTime(2026)),
    });
    expect(legacy.amountKrw, 950);
    expect(legacy.receiptItems, isEmpty);
    expect(legacy.paymentMethod, isNull);
  });

  test('현재 환율이나 할인 표시에 관계없이 기록 당시 실제 결제액으로 계산한다', () {
    final e = expense();
    expect(api.LedgerCalc.spentKrw([e]), 12.5 * 1300.5);
    expect(
      api.LedgerCalc.remainingKrw(trip('test'), [e]),
      100000 - 12.5 * 1300.5,
    );
    expect(
      api.LedgerCalc.spentKrw([
        e.copyWith(status: api.ExpenseStatus.cancelled),
      ]),
      0,
    );
    expect(api.RateApi.krwPer('USD'), 1500);
  });

  test('다른 결제 통화도 같은 팀 환율 API에서 읽고 잘못된 환율은 버린다', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'result': 'success',
          'rates': {
            'USD': 1 / 1500,
            'SGD': 1 / 1000,
            'XYZ': 0,
            'BAD': -1,
            'oops': 2,
          },
        }),
        200,
      ),
    );
    await api.RateApi.load(force: true, client: client);
    expect(api.RateApi.krwPer('SGD'), 1000);
    expect(api.RateApi.krwPer('XYZ'), 0);
    expect(api.RateApi.krwPer('BAD'), 0);
    expect(api.RateApi.krwPer('oops'), 0);
    client.close();
  });

  test('저장 경계에서 잘못된 금액·환율·영수증·메모를 거부한다', () {
    expect(
      () => api.ExpenseApi.validate(expense(amount: 0.5)),
      returnsNormally,
    );
    for (final invalid in [
      expense(amount: double.nan),
      expense(amount: -1),
      expense(amount: 0),
      expense().copyWith(rate: 0),
      expense().copyWith(rate: double.infinity),
      expense().copyWith(place: ' '),
      expense().copyWith(memo: 'x' * 301),
      expense().copyWith(
        receiptItems: const [api.ReceiptItem(name: '', quantity: 1, amount: 2)],
      ),
    ]) {
      expect(
        () => api.ExpenseApi.validate(invalid),
        throwsA(isA<api.ApiException>()),
      );
    }
  });

  test('장부 상태가 여행별로 격리되고 삭제·구독 오류·닫힘을 처리한다', () async {
    final trips = StreamController<api.Trip?>();
    final entries = StreamController<List<api.Expense>>();
    final first = TripStore(
      tripId: 'one',
      tripStream: trips.stream,
      expenseStream: entries.stream,
    );
    final second = RecordingStore([]);
    expect(first.isLoading, isTrue);
    trips.add(trip('one'));
    await Future<void>.delayed(Duration.zero);
    expect(first.isLoading, isTrue);
    entries.add([expense()]);
    await Future<void>.delayed(Duration.zero);
    final held = first.trip!;
    expect(first.isLoading, isFalse);
    expect(SpendingSummary(held).netKrw, (12.5 * 1300.5).truncate());
    expect(second.trip!.expenses, isEmpty);
    trips.add(trip('one').copyWith(name: '새 이름', budget: 200000));
    await Future<void>.delayed(Duration.zero);
    expect(identical(held, first.trip), isTrue);
    expect(held.name, '새 이름');
    expect(held.expenses.single.id, 'receipt');
    entries.addError(const api.ApiException('권한 없음'));
    await Future<void>.delayed(Duration.zero);
    expect(first.error, isA<api.ApiException>());
    trips.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(first.trip, isNull);
    first.dispose();
    second.dispose();
    await expectLater(
      first.saveExpense('one', expense()),
      throwsA(isA<api.ApiException>()),
    );
    await trips.close();
    await entries.close();
  });

  testWidgets('기존 금액의 소수점·저장 환율·영수증을 메모 수정 후에도 보존한다', (tester) async {
    final e = expense();
    final store = RecordingStore([e]);
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ExpenseFormScreen(trip: store.trip!, store: store, expense: e),
      ),
    );
    expect(find.text('12.5'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('expense-memo')));
    await tester.enterText(
      find.byKey(const ValueKey('expense-memo')),
      '수정한 메모',
    );
    await tester.tap(find.text('저장').last);
    await tester.pumpAndSettle();
    expect(store.saved!.amount, 12.5);
    expect(store.saved!.rate, 1300.5);
    expect(store.saved!.memo, '수정한 메모');
    expect(store.saved!.receiptItems.single.name, 'Coffee');
    expect(store.saved!.receiptTaxes.single.amount, 1.5);
    expect(store.saved!.receiptAdjustments!.discount, 2);
    store.dispose();
  });

  testWidgets('저장 실패 때 입력 내용을 유지하고 재시도할 수 있다', (tester) async {
    final e = expense();
    final store = RecordingStore([e])..failSave = true;
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ExpenseFormScreen(trip: store.trip!, store: store, expense: e),
      ),
    );
    await tester.tap(find.text('저장').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('입력 내용을 유지'), findsOneWidget);
    expect(find.text('12.5'), findsOneWidget);
    expect(store.saved, isNull);
    store.dispose();
  });

  testWidgets('팀 데이터로 기존 장부 목록·필터·상세 화면이 열린다', (tester) async {
    final store = RecordingStore([expense()]);
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LedgerScreen(trip: store.trip!, store: store),
      ),
    );
    expect(find.byKey(const ValueKey('ledger-budget-card')), findsOneWidget);
    expect(find.text('카페'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('ledger-filter-menu')),
    );
    await tester.tap(find.byKey(const ValueKey('ledger-filter-menu')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('목록 설정'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('카페'));
    await tester.tap(find.text('카페'));
    await tester.pumpAndSettle();
    expect(find.text('지출 상세'), findsOneWidget);
    expect(find.textContaining('기록 당시 환산'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
