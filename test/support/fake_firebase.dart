import 'dart:async';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as db;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트용 가짜 Firebase. 실제 팀 API(AuthApi·TripApi·ExpenseApi)가 이 위에서 돈다.
/// 사용자 `owner`로 로그인된 상태에서 시작한다.
({TestAuth auth, TestFirestore firestore}) installFakeFirebase() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final testAuth = TestAuth();
  final firestore = TestFirestore();
  setUpAll(() async {
    await Firebase.initializeApp();
    auth.FirebaseAuthPlatform.instance = testAuth;
    db.FirebaseFirestorePlatform.instance = firestore;
  });
  return (auth: testAuth, firestore: firestore);
}

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

  @override
  Future<void> signOut() async {
    signedIn = false;
    events.add(null);
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

  /// 쓰기가 일어날 때마다 열려 있는 구독에 새 스냅샷을 보낸다.
  final _changes = StreamController<void>.broadcast(sync: true);
  void changed() => _changes.add(null);
  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

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

final _metadata = db.InternalSnapshotMetadata(
  hasPendingWrites: false,
  isFromCache: false,
);

class TestCollection extends db.CollectionReferencePlatform {
  TestCollection(TestFirestore super.firestore, super.path) {
    parameters['orderBy'] = <List<dynamic>>[];
  }
  TestFirestore get _db => firestore as TestFirestore;

  db.QuerySnapshotPlatform _read() => db.QuerySnapshotPlatform(
    [
      for (final entry in _db.documents.entries)
        if (entry.key.startsWith('$path/') &&
            entry.key.split('/').length == path.split('/').length + 1)
          db.DocumentSnapshotPlatform(
            firestore,
            entry.key,
            entry.value,
            _metadata,
          ),
    ],
    [],
    db.SnapshotMetadataPlatform(false, false),
  );

  @override
  db.QueryPlatform orderBy(Iterable<List<dynamic>> orders) => this;
  @override
  Stream<db.QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required db.ListenSource listenSource,
  }) => _db._live(_read);
  @override
  Future<db.QuerySnapshotPlatform> get([
    db.GetOptions options = const db.GetOptions(),
  ]) async => _read();
  @override
  db.DocumentReferencePlatform doc([String? id]) =>
      TestDocument(_db, '$path/${id ?? 'generated-${++_db.generated}'}');
}

class TestDocument extends db.DocumentReferencePlatform {
  TestDocument(TestFirestore super.firestore, super.path);
  TestFirestore get _db => firestore as TestFirestore;
  Map<String, Map<String, dynamic>> get documents => _db.documents;

  db.DocumentSnapshotPlatform _read() =>
      db.DocumentSnapshotPlatform(firestore, path, documents[path], _metadata);

  @override
  Future<void> set(Map<String, dynamic> data, [db.SetOptions? options]) async {
    documents[path] = {...?documents[path], ...data};
    _db.changed();
  }

  @override
  Future<void> update(Map<db.FieldPath, dynamic> data) async {
    if (!documents.containsKey(path)) throw StateError('Missing document');
    documents[path]!.addAll(
      data.map((key, value) => MapEntry(key.components.join('.'), value)),
    );
    _db.changed();
  }

  @override
  Future<void> delete() async {
    documents.remove(path);
    _db.changed();
  }

  @override
  Stream<db.DocumentSnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required db.ListenSource listenSource,
  }) => _db._live(_read);
  @override
  Future<db.DocumentSnapshotPlatform> get([
    db.GetOptions options = const db.GetOptions(),
  ]) async => _read();
}
