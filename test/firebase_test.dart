// Firebase 모드 경로를 실제 프로젝트 없이 검사한다.
// fake_cloud_firestore / firebase_auth_mocks 는 메모리 안에서 도는 가짜라
// 네트워크도 키도 필요 없다.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import 'package:tripapp/trip_home/data/trip_repository.dart';
import 'package:tripapp/trip_home/data/trip_store.dart';
import 'package:tripapp/trip_home/models/country.dart';
import 'package:tripapp/trip_home/models/trip.dart';
import 'package:tripapp/trip_home/services/auth_service.dart';
import 'package:tripapp/trip_home/services/session.dart';

/// 스냅샷 스트림이 한 바퀴 돌 시간을 준다.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

Trip _trip(String id, {String name = '일본 여행'}) => Trip(
      id: id,
      name: name,
      country: countryByCode('JPY')!,
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 5),
      budgetKrw: 1200000,
    );

Expense _expense(String id) => Expense(
      id: id,
      icon: '🍜',
      place: '이치란 라멘',
      amount: 1200,
      category: '식비',
      date: DateTime(2026, 10, 2, 12, 30, 15),
    );

void main() {
  group('FirestoreTripRepository + TripStore', () {
    late FakeFirebaseFirestore db;
    late TripStore store;

    CollectionReference<Map<String, dynamic>> tripsOf(String uid) =>
        db.collection('users').doc(uid).collection('trips');

    setUp(() {
      db = FakeFirebaseFirestore();
      store = TripStore();
    });

    test('붙자마자는 로딩 중, 첫 스냅샷이 오면 끝난다', () async {
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      expect(store.isLoading, isTrue);
      await settle();
      expect(store.isLoading, isFalse);
      expect(store.isEmpty, isTrue);
    });

    test('여행 추가 -> users/{uid}/trips/{id} 에 저장', () async {
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      await settle();

      store.add(_trip('t1'));
      await settle();

      final doc = await tripsOf('u1').doc('t1').get();
      expect(doc.exists, isTrue);
      expect(doc['name'], '일본 여행');
      expect(doc['currency'], 'JPY');
      expect(doc['budgetKrw'], 1200000);
      expect(store.trips.single.id, 't1');
    });

    test('지출은 records 하위 컬렉션에 시분초까지 저장', () async {
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      await settle();
      store.add(_trip('t1'));
      await settle();

      await store.addExpense('t1', _expense('e1'));
      await settle();

      final rec =
          await tripsOf('u1').doc('t1').collection('records').doc('e1').get();
      expect(rec['place'], '이치란 라멘');
      expect((rec['date'] as Timestamp).toDate(), DateTime(2026, 10, 2, 12, 30, 15));
      expect(store.byId('t1')!.expenses.single.amount, 1200);
    });

    test('다른 기기에서 바뀐 내용이 들어와도 Trip 객체는 그대로 (열린 화면이 안 끊긴다)',
        () async {
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      await settle();
      store.add(_trip('t1'));
      await settle();

      final held = store.byId('t1')!; // 03 화면이 들고 있는 객체라고 치자

      // 다른 기기가 Firestore 를 직접 고친다
      await tripsOf('u1').doc('t1').update({'name': '오사카 여행'});
      await tripsOf('u1').doc('t1').collection('records').doc('e9').set({
        'icon': '🚃',
        'place': 'JR 패스',
        'amount': 3500, // int 로 들어와도 double 로 읽혀야 한다
        'category': '교통',
        'date': Timestamp.fromDate(DateTime(2026, 10, 3)),
      });
      await settle();

      expect(identical(store.byId('t1'), held), isTrue);
      expect(held.name, '오사카 여행');
      expect(held.expenses.single.amount, 3500.0);
    });

    test('여행 편집(이름·기간·예산)이 저장되고 createdAt 은 그대로', () async {
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      await settle();
      store.add(_trip('t1'));
      await settle();
      final createdAt = (await tripsOf('u1').doc('t1').get())['createdAt'];

      store.update('t1',
          name: '오사카 여행',
          start: DateTime(2026, 11, 1),
          end: DateTime(2026, 11, 3),
          budgetKrw: 500000);
      await settle();

      final doc = await tripsOf('u1').doc('t1').get();
      expect(doc['name'], '오사카 여행');
      expect((doc['start'] as Timestamp).toDate(), DateTime(2026, 11, 1));
      expect((doc['end'] as Timestamp).toDate(), DateTime(2026, 11, 3));
      expect(doc['budgetKrw'], 500000);
      expect(doc['createdAt'], createdAt);
    });

    test('여행 삭제 시 records 도 같이 지운다', () async {
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      await settle();
      store.add(_trip('t1'));
      await settle();
      await store.addExpense('t1', _expense('e1'));
      await settle();

      store.remove('t1');
      await settle();

      expect((await tripsOf('u1').doc('t1').get()).exists, isFalse);
      final records =
          await tripsOf('u1').doc('t1').collection('records').get();
      expect(records.docs, isEmpty);
      expect(store.isEmpty, isTrue);
    });

    test('사용자끼리 데이터가 섞이지 않는다', () async {
      await tripsOf('someone-else').doc('x').set({
        'name': '남의 여행',
        'currency': 'USD',
        'start': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'end': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'budgetKrw': 1,
      });
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      await settle();
      expect(store.isEmpty, isTrue);
    });

    test('모르는 통화 코드 문서는 건너뛴다', () async {
      await tripsOf('u1').doc('bad').set({
        'name': '???',
        'currency': 'XXX',
        'start': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'end': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'budgetKrw': 1,
      });
      store.connect(FirestoreTripRepository(uid: 'u1', db: db));
      await settle();
      expect(store.isEmpty, isTrue);
    });
  });

  group('로그인 ↔ 저장소 연결', () {
    test('로그인하면 그 사람 경로에 붙고, 로그아웃하면 비운다', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('users')
          .doc('local:a@a.com')
          .collection('trips')
          .doc('t1')
          .set({
        'name': 'A 의 여행',
        'currency': 'JPY',
        'start': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'end': Timestamp.fromDate(DateTime(2026, 10, 5)),
        'budgetKrw': 100,
      });

      final auth = LocalAuthService();
      final store = TripStore();
      bindTripStoreToAuth(auth, store,
          repoFor: (uid) => FirestoreTripRepository(uid: uid, db: db));

      await auth.signIn('a@a.com', '123456');
      await settle();
      expect(store.trips.single.name, 'A 의 여행');

      await auth.signOut();
      await settle();
      expect(store.isEmpty, isTrue);
    });
  });

  group('FirebaseAuthService', () {
    test('로그인하면 currentUser 가 채워진다', () async {
      final mock = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'a@a.com'),
      );
      final auth = FirebaseAuthService(mock);
      await settle();
      expect(auth.isReady, isTrue);
      expect(auth.isSignedIn, isFalse);

      await auth.signIn('a@a.com', '123456');
      await settle();
      expect(auth.currentUser?.uid, 'u1');

      await auth.signOut();
      await settle();
      expect(auth.isSignedIn, isFalse);
    });

    test('Firebase 에러가 한국어 AuthException 으로 바뀐다', () async {
      final mock = MockFirebaseAuth();
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(mock)
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      final auth = FirebaseAuthService(mock);
      expect(
        () => auth.signIn('a@a.com', 'wrong!'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', '이메일 또는 비밀번호가 맞지 않아요')),
      );
    });

    test('로컬 모드와 Firebase 모드의 문구가 같다', () async {
      final local = LocalAuthService();
      await expectLater(
        local.signIn('a@a.com', '123'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            FirebaseAuthService.messageFor('weak-password'))),
      );
      await expectLater(
        local.signIn('not-an-email', '123456'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            FirebaseAuthService.messageFor('invalid-email'))),
      );
    });
  });
}
