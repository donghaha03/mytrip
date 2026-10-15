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
import 'package:tripapp/auth_gate.dart';
import 'package:tripapp/login_screen.dart';
import 'package:tripapp/password_reset_screen.dart';
import 'package:tripapp/signup_screen.dart';

class TestAuth extends auth.FirebaseAuthPlatform {
  String? email, password;
  int signIns = 0, signUps = 0, resets = 0, verifications = 0;
  late final user = TestUser(this);
  @override
  auth.FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  auth.FirebaseAuthPlatform setInitialValues({
    auth.InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  auth.UserPlatform get currentUser => user;
  @override
  Future<auth.UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    this.email = email;
    this.password = password;
    signIns++;
    return TestCredential(this, user);
  }

  @override
  Future<auth.UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    this.email = email;
    this.password = password;
    signUps++;
    return TestCredential(this, user);
  }

  @override
  Future<void> sendPasswordResetEmail(
    String email, [
    auth.ActionCodeSettings? actionCodeSettings,
  ]) async {
    this.email = email;
    resets++;
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
  @override
  Future<void> sendEmailVerification(
    auth.ActionCodeSettings? actionCodeSettings,
  ) async {
    (this.auth as TestAuth).verifications++;
  }
}

class TestCredential extends auth.UserCredentialPlatform {
  TestCredential(auth.FirebaseAuthPlatform auth, auth.UserPlatform user)
    : super(auth: auth, user: user);
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
  TestCollection(TestFirestore super.firestore, super.path);
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
    testAuth.signIns = testAuth.signUps = testAuth.resets =
        testAuth.verifications = 0;
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

  test('AuthApi가 이메일을 정규화하고 비밀번호 공백은 보존한다', () async {
    await AuthApi.signIn(' TEST@EXAMPLE.COM ', ' pass word ');
    expect(testAuth.email, 'test@example.com');
    expect(testAuth.password, ' pass word ');
    expect(testAuth.signIns, 1);
    expect(AuthApi.validatePassword('short'), isNull);
    expect(AuthApi.validateNewPassword('abc123'), isNotNull);
  });

  testWidgets('AuthGate가 로그인·로그아웃 상태에 따라 화면을 바꾼다', (tester) async {
    final users = StreamController<User?>(sync: true);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(userChanges: users.stream, home: const Text('여행 목록')),
      ),
    );
    users.add(null);
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    users.add(AuthApi.user);
    await tester.pump();
    expect(find.text('여행 목록'), findsOneWidget);
    users.add(null);
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(users.close);
  });

  testWidgets('재설정 화면은 AuthApi로 실제 전송을 요청한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordResetScreen()));
    await tester.enterText(find.byType(TextField), ' TEST@EXAMPLE.COM ');
    final button = find.widgetWithText(ElevatedButton, '재설정 이메일 보내기');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(testAuth.resets, 1);
    expect(testAuth.email, 'test@example.com');
    expect(find.text('비밀번호 재설정 이메일을 전송했습니다.'), findsOneWidget);
  });

  testWidgets('가입 화면은 공용 검증과 AuthApi의 인증 메일을 사용한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), 'abc123');
    await tester.enterText(fields.at(2), 'abc123');
    final button = find.widgetWithText(ElevatedButton, '회원가입');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(testAuth.signUps, 0);
    expect(find.text('비밀번호는 8자 이상이어야 해요'), findsOneWidget);
    await tester.enterText(fields.at(1), 'abc12345');
    await tester.enterText(fields.at(2), 'abc12345');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(testAuth.signUps, 1);
    expect(testAuth.verifications, 1);
  });
}
