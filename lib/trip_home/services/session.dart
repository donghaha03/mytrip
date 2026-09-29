import '../data/trip_repository.dart';
import '../data/trip_store.dart';
import 'auth_service.dart';

/// 로그인 사용자가 바뀔 때마다 TripStore 를 그 사람의 Firestore 경로에 붙인다.
///
///   로그인    -> users/{uid}/trips 구독 시작
///   로그아웃  -> 구독 해제 + 목록 비움
///
/// Firebase 모드에서만 main() 이 부른다. [repoFor] 는 테스트에서 가짜
/// Firestore 를 끼우려고 뺐다.
void bindTripStoreToAuth(
  AuthService auth,
  TripStore store, {
  TripRepository Function(String uid)? repoFor,
}) {
  final make = repoFor ?? (uid) => FirestoreTripRepository(uid: uid);
  String? lastUid;
  var first = true;

  void sync() {
    final uid = auth.currentUser?.uid;
    // notifyListeners 는 uid 가 안 바뀌어도 불린다 — 같은 사람이면 다시 안 붙는다
    if (!first && uid == lastUid) return;
    first = false;
    lastUid = uid;
    store.connect(uid == null ? null : make(uid));
  }

  auth.addListener(sync);
  sync();
}
