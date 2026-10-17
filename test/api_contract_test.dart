import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as db;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripapp/api/api.dart';
import 'package:tripapp/ledger_page.dart';
import 'package:tripapp/ledger/screens/ledger_screen.dart';

class TestAuth extends auth.FirebaseAuthPlatform {
  late final user = TestUser(this);
  bool signedIn = true;
  final events = StreamController<auth.UserPlatform?>.broadcast(sync: true);
  @override
  auth.FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  auth.FirebaseAuthPlatform setInitialValues({
    auth.InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  auth.UserPlatform? get currentUser => signedIn ? user : null;
  @override
  Stream<auth.UserPlatform?> userChanges() async* {
    yield currentUser;
    yield* events.stream;
  }
}

class TestFactor extends auth.MultiFactorPlatform {
  TestFactor(super.auth);
}

class TestUser extends auth.UserPlatform {
  TestUser(TestAuth auth) : super(auth, TestFactor(auth), authDetails());
  static auth.InternalUserDetails authDetails() => auth.InternalUserDetails(
    userInfo: auth.InternalUserInfo(
      uid: 'owner',
      isAnonymous: false,
      isEmailVerified: false,
    ),
    providerData: [],
  );
}

class TestFirestore extends db.FirebaseFirestorePlatform {
  final documents = <String, Map<String, dynamic>>{};
  int generated = 0;
  @override
  db.FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;
  @override
  db.Settings get settings => const db.Settings();
  @override
  db.CollectionReferencePlatform collection(String path) =>
      TestCollection(this, path);
  @override
  db.DocumentReferencePlatform doc(String path) => TestDocument(this, path);
}

class TestCollection extends db.CollectionReferencePlatform {
  TestCollection(TestFirestore super.firestore, super.path) {
    parameters['orderBy'] = <List<dynamic>>[];
  }
  @override
  db.QueryPlatform orderBy(Iterable<List<dynamic>> orders) => this;
  @override
  Stream<db.QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required db.ListenSource listenSource,
  }) => Stream.value(
    db.QuerySnapshotPlatform(
      [
        for (final entry in (firestore as TestFirestore).documents.entries)
          if (entry.key.startsWith('$path/') &&
              entry.key.split('/').length == path.split('/').length + 1)
            db.DocumentSnapshotPlatform(
              firestore,
              entry.key,
              entry.value,
              db.InternalSnapshotMetadata(
                hasPendingWrites: false,
                isFromCache: false,
              ),
            ),
      ],
      [],
      db.SnapshotMetadataPlatform(false, false),
    ),
  );
  @override
  db.DocumentReferencePlatform doc([String? id]) => TestDocument(
    firestore as TestFirestore,
    '$path/${id ?? 'generated-${++(firestore as TestFirestore).generated}'}',
  );
}

class TestDocument extends db.DocumentReferencePlatform {
  TestDocument(TestFirestore super.firestore, super.path);
  Map<String, Map<String, dynamic>> get documents =>
      (firestore as TestFirestore).documents;
  @override
  Future<void> set(Map<String, dynamic> data, [db.SetOptions? options]) async {
    documents[path] = {...?documents[path], ...data};
  }

  @override
  Future<void> update(Map<db.FieldPath, dynamic> data) async {
    if (!documents.containsKey(path)) throw StateError('Missing document');
    documents[path]!.addAll(
      data.map((key, value) => MapEntry(key.components.join('.'), value)),
    );
  }

  @override
  Future<void> delete() async => documents.remove(path);
  @override
  Stream<db.DocumentSnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required db.ListenSource listenSource,
  }) => Stream.value(
    db.DocumentSnapshotPlatform(
      firestore,
      path,
      documents[path],
      db.InternalSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final testAuth = TestAuth();
  final firestore = TestFirestore();
  const collection = 'users/owner/trips/trip/expenses';

  setUpAll(() async {
    await Firebase.initializeApp();
    auth.FirebaseAuthPlatform.instance = testAuth;
    db.FirebaseFirestorePlatform.instance = firestore;
  });
  setUp(() async {
    firestore.documents.clear();
    testAuth.signedIn = true;
    SharedPreferences.setMockInitialValues({
      'rates': jsonEncode({'USD': 1 / 1500, 'KRW': 1}),
      'rates_time': DateTime.now().toIso8601String(),
    });
    await RateApi.load();
  });

  test('add가 ID와 환율을 정하고 영수증 필드와 소수점 결제액을 저장한다', () async {
    final receiptDate = DateTime(2026, 10, 2);
    await ExpenseApi.add(
      'trip',
      category: '식비',
      place: ' 카페 ',
      amount: 12.5,
      currency: 'USD',
      date: receiptDate,
      memo: '영수증',
      paymentMethod: PaymentMethod.card,
      isTaxFree: true,
      receiptFingerprint: 'receipt',
      receiptItems: const [
        ReceiptItem(name: 'Coffee', quantity: 1, amount: 12.5),
      ],
      receiptTaxes: const [
        ReceiptTax(label: '세금', amount: 1, currency: 'USD', included: true),
      ],
      receiptAdjustments: const ReceiptAdjustments(
        discount: 2,
        currency: 'USD',
      ),
    );
    final path = firestore.documents.keys.single;
    expect(path, startsWith('$collection/generated-'));
    final expense = Expense.fromMap(
      path.split('/').last,
      firestore.documents[path]!,
    );
    expect(expense.place, '카페');
    expect(expense.rate, 1500);
    expect(expense.amountKrw, 18750);
    expect(expense.date, receiptDate);
    expect(expense.memo, '영수증');
    expect(expense.paymentMethod, PaymentMethod.card);
    expect(expense.isTaxFree, isTrue);
    expect(expense.receiptItems.single.name, 'Coffee');
    expect(expense.receiptTaxes.single.amount, 1);
    expect(expense.receiptAdjustments!.discount, 2);
    final original = expense.copyWith(rate: 1300.5, memo: '수정');
    firestore.documents[path]!['otherTeamField'] = '보존';
    await ExpenseApi.update('trip', original);
    final updated = Expense.fromMap(original.id, firestore.documents[path]!);
    expect(updated.rate, 1300.5);
    expect(updated.date, receiptDate);
    expect(updated.receiptItems.single.name, 'Coffee');
    expect(firestore.documents[path]!['otherTeamField'], '보존');
    await ExpenseApi.delete('trip', original.id);
    expect(firestore.documents, isEmpty);
    await ExpenseApi.restore('trip', original);
    expect(
      Expense.fromMap(original.id, firestore.documents[path]!).toMap(),
      original.toMap(),
    );
  });

  test('add 기본 날짜와 잘못된 입력·환율 없음 처리', () async {
    final before = DateTime.now();
    await ExpenseApi.add(
      'trip',
      category: '식비',
      place: '카페',
      amount: 0.5,
      currency: 'USD',
    );
    final row = firestore.documents.entries.single;
    expect(Expense.fromMap('id', row.value).date.isBefore(before), isFalse);
    await expectLater(
      ExpenseApi.add(
        'trip',
        category: '식비',
        place: '카페',
        amount: 10,
        currency: 'XYZ',
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      ExpenseApi.add(
        'trip',
        category: '식비',
        place: '카페',
        amount: double.nan,
        currency: 'USD',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(firestore.documents.length, 1);
  });

  testWidgets('공용 진입점은 선택한 여행만 열고 더보기는 호출자에게 전달한다', (tester) async {
    for (final id in ['first', 'second']) {
      firestore.documents['users/owner/trips/$id'] = Trip(
        id: id,
        name: id == 'first' ? '첫 여행' : '두 번째 여행',
        budget: 100000,
        currency: 'USD',
        start: DateTime(2026),
        end: DateTime(2027),
      ).toMap();
      firestore.documents['users/owner/trips/$id/expenses/entry'] = Expense(
        id: 'entry',
        category: '식비',
        place: id == 'first' ? '첫 카페' : '두 번째 카페',
        amount: 12.5,
        currency: 'USD',
        rate: 1300.5,
        date: DateTime(2026, 10, 3),
      ).toMap();
    }
    var more = 0;
    Widget page(String id) => MaterialApp(
      home: LedgerPage(tripId: id, onMore: () => more++),
    );
    await tester.pumpWidget(page('first'));
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsOneWidget);
    expect(find.textContaining('첫 여행'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('첫 카페'), 200);
    expect(find.text('첫 카페'), findsOneWidget);
    await tester.tap(find.byTooltip('더보기'));
    expect(more, 1);
    await tester.pumpWidget(page('second'));
    await tester.pumpAndSettle();
    expect(find.textContaining('두 번째 여행'), findsOneWidget);
    expect(find.text('첫 카페'), findsNothing);
    await tester.scrollUntilVisible(find.text('두 번째 카페'), 200);
    expect(find.text('두 번째 카페'), findsOneWidget);
    testAuth.signedIn = false;
    testAuth.events.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsNothing);
    expect(find.text('로그인 후 여행 장부를 열어주세요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('없는 여행은 다른 화면으로 이동하지 않고 장부에서 안내한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LedgerPage(tripId: 'missing')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LedgerScreen), findsNothing);
    expect(find.text('삭제되었거나 찾을 수 없는 여행이에요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
