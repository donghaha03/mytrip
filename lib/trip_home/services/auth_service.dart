import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 로그인한 사용자. Firebase 의 User 를 화면 쪽에 직접 노출하지 않으려고 감쌌다.
@immutable
class AppUser {
  const AppUser({required this.uid, this.email});

  final String uid;
  final String? email;
}

/// 화면에 그대로 보여줘도 되는 한국어 메시지를 담은 예외.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 로그인 담당은 이 인터페이스만 쓰면 된다. 로컬/Firebase 어느 모드든 같다.
///
///   await authService.signIn(email, password);   // 실패 시 AuthException
///   await authService.signUp(email, password);
///   await authService.signOut();
///   authService.currentUser  /  authService.isSignedIn
///
/// ChangeNotifier 라서 로그인 상태가 바뀌면 AuthGate 가 알아서 화면을 바꾼다.
/// 로그인 성공 후에 Navigator.push 로 직접 넘길 필요 없다.
abstract class AuthService extends ChangeNotifier {
  AppUser? get currentUser;
  bool get isSignedIn => currentUser != null;

  /// 앱 시작 직후 저장된 로그인 상태를 아직 확인 중이면 false.
  /// (웹 Firebase 는 새로고침 후 복원에 잠깐 걸린다)
  bool get isReady;

  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}

/// 앱 전역 인스턴스. main() 에서 모드에 맞게 바꿔 끼운다.
AuthService authService = LocalAuthService();

// ---------------------------------------------------------------------------
// 로컬 임시 모드
// ---------------------------------------------------------------------------

/// Firebase 없이 도는 가짜 로그인.
/// 형식만 맞으면 통과시키되, 검증 규칙과 에러 문구는 Firebase 쪽과 맞춰 둔다 —
/// 로그인 화면을 로컬에서 만들어도 Firebase 모드에서 똑같이 동작하게.
class LocalAuthService extends AuthService {
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  bool get isReady => true;

  @override
  Future<void> signIn(String email, String password) async {
    _validate(email, password);
    _user = AppUser(uid: 'local:${email.trim()}', email: email.trim());
    notifyListeners();
  }

  @override
  Future<void> signUp(String email, String password) => signIn(email, password);

  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }

  static void _validate(String email, String password) {
    if (!email.contains('@') || email.trim().length < 3) {
      throw const AuthException(_Msg.invalidEmail);
    }
    if (password.length < 6) {
      throw const AuthException(_Msg.weakPassword);
    }
  }
}

// ---------------------------------------------------------------------------
// Firebase 모드
// ---------------------------------------------------------------------------

class FirebaseAuthService extends AuthService {
  FirebaseAuthService([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance {
    _sub = _auth.authStateChanges().listen((u) {
      _user = u == null ? null : AppUser(uid: u.uid, email: u.email);
      _ready = true;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _sub;
  AppUser? _user;
  bool _ready = false;

  @override
  AppUser? get currentUser => _user;

  @override
  bool get isReady => _ready;

  @override
  Future<void> signIn(String email, String password) => _guard(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> signUp(String email, String password) => _guard(() => _auth
      .createUserWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<Object?> Function() run) async {
    try {
      await run();
    } on FirebaseAuthException catch (e) {
      throw AuthException(messageFor(e.code));
    }
  }

  /// Firebase 에러 코드 -> 화면용 문구. 테스트에서도 쓰려고 공개.
  static String messageFor(String code) => switch (code) {
        'invalid-email' => _Msg.invalidEmail,
        'weak-password' => _Msg.weakPassword,
        'email-already-in-use' => '이미 가입된 이메일이에요',
        // 최신 Firebase 는 보안상 user-not-found / wrong-password 를
        // invalid-credential 하나로 뭉쳐서 돌려준다.
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' =>
          '이메일 또는 비밀번호가 맞지 않아요',
        'too-many-requests' => '시도가 너무 많아요. 잠시 후 다시 해 주세요',
        'network-request-failed' => '네트워크 연결을 확인해 주세요',
        'operation-not-allowed' =>
          'Firebase 콘솔에서 이메일/비밀번호 로그인이 꺼져 있어요',
        _ => '로그인에 실패했어요 ($code)',
      };

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class _Msg {
  static const invalidEmail = '이메일 형식이 올바르지 않아요';
  static const weakPassword = '비밀번호는 6자 이상이어야 해요';
}
