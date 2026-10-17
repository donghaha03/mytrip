import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'api_exception.dart';
import 'social_config.dart';

/// 로그인 / 회원가입 / 계정 관리 (이메일, 구글)
///
/// 화면 사용 예:
///   TextFormField(validator: AuthApi.validateEmail)
///   try { await AuthApi.signIn(email, pw); }
///   catch (e) { showError(AuthApi.errorMessage(e)); }
///
///   final ok = await AuthApi.signInWithGoogle();   // false = 사용자가 취소
///
/// ※ main()에서 Firebase 초기화 뒤 `await AuthApi.initSocial();` 를 한 번 호출하세요.
/// ※ Firebase 콘솔에서 이메일/비밀번호, Google 로그인을 사용 설정해야 합니다.
class AuthApi {
  AuthApi._();
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // ---------------------------------------------------------------------------
  // 상태 조회
  // ---------------------------------------------------------------------------

  static User? get user => _auth.currentUser;
  static bool get isLoggedIn => user != null;

  /// 로그인된 상태에서만 호출하세요 (다른 API들이 내부적으로 사용)
  static String get uid => _auth.currentUser!.uid;

  static String? get email => user?.email;

  /// 표시 이름. 없으면 이메일 앞부분, 그것도 없으면 '사용자'
  static String get displayName {
    final n = user?.displayName;
    if (n != null && n.trim().isNotEmpty) return n;
    final mail = user?.email;
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return '사용자';
  }

  static bool get isEmailVerified => user?.emailVerified ?? false;

  static bool _hasProvider(String id) =>
      user?.providerData.any((p) => p.providerId == id) ?? false;

  static bool get isPasswordUser => _hasProvider('password');
  static bool get isGoogleUser => _hasProvider('google.com');

  /// 이메일 가입자인데 아직 메일 인증을 안 한 상태 (인증 안내 화면 분기용)
  static bool get needsEmailVerification => isPasswordUser && !isEmailVerified;

  /// 프로필 화면 표시용: "이메일" / "Google"
  static String get loginMethodLabel {
    if (isPasswordUser) return '이메일';
    if (isGoogleUser) return 'Google';
    return '알 수 없음';
  }

  /// 로그인/로그아웃 변화 스트림 (앱 최상단 화면 분기용)
  static Stream<User?> get changes => _auth.authStateChanges();

  /// 로그인/로그아웃 + 프로필(이름, 인증 여부) 변경까지 감지.
  static Stream<User?> get userChanges => _auth.userChanges();


  static String _normalizeEmail(String v) => v.trim().toLowerCase();

  static String? validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '이메일을 입력해주세요';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return '이메일 형식이 올바르지 않아요';
    }
    return null;
  }

  /// 로그인용: 비어 있는지만 확인 (예전에 만든 짧은 비밀번호도 로그인은 되어야 함)
  static String? validatePassword(String? v) =>
      (v == null || v.isEmpty) ? '비밀번호를 입력해주세요' : null;

  /// 가입/비밀번호 변경용: 8자 이상, 영문+숫자 포함
  static String? validateNewPassword(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 입력해주세요';
    if (v.length < 8) return '비밀번호는 8자 이상이어야 해요';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return '영문과 숫자를 함께 사용해주세요';
    }
    return null;
  }

  /// 비밀번호 확인 칸용. 사용 예:
  ///   validator: AuthApi.validatePasswordMatch(() => pwController.text)
  static String? Function(String?) validatePasswordMatch(
    String Function() password,
  ) =>
      (v) => v == password() ? null : '비밀번호가 서로 일치하지 않습니다.';

  static String? validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '이름을 입력해주세요.';
    if (s.length > 20) return '이름은 20자 이하로 입력해주세요';
    return null;
  }

  // ---------------------------------------------------------------------------
  // 소셜 로그인 초기화 (main에서 한 번)
  // ---------------------------------------------------------------------------

  static bool _socialReady = false;

  static Future<void> initSocial() async {
    if (_socialReady) return;
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize(
        serverClientId: SocialConfig.googleServerClientId.isEmpty
            ? null
            : SocialConfig.googleServerClientId,
      );
    }
    _socialReady = true;
  }

  // ---------------------------------------------------------------------------
  // 이메일 가입 / 로그인 / 로그아웃
  // ---------------------------------------------------------------------------

  /// 회원가입 (가입 후 자동 로그인됨).
  ///
  static Future<void> signUp(
    String email,
    String password, {
    String? name,
    bool sendVerification = true,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );
    final u = cred.user;
    if (u == null) return;

    if (name != null && name.trim().isNotEmpty) {
      try {
        await u.updateDisplayName(name.trim());
        await u.reload();
      } catch (_) {
        // 이름은 나중에 프로필에서 다시 설정 가능
      }
    }
    if (sendVerification) {
      try {
        await u.sendEmailVerification();
      } catch (_) {
        // 인증 메일은 나중에 다시 보낼 수 있음 (sendEmailVerification)
      }
    }
  }

  static Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(
        email: _normalizeEmail(email),
        password: password,
      );

  /// 로그아웃 (구글 세션도 함께 정리)
  static Future<void> signOut() async {
    if (_socialReady && !kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // 구글 로그인
  // ---------------------------------------------------------------------------

  /// 구글 로그인. 성공 true, 사용자가 취소하면 false
  static Future<bool> signInWithGoogle() async {
    await initSocial();
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return true;
    }
    final cred = await _googleCredential();
    if (cred == null) return false;
    await _auth.signInWithCredential(cred);
    return true;
  }

  static Future<AuthCredential?> _googleCredential() async {
    await initSocial();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const ApiException('구글 인증 정보를 가져오지 못했어요');
      }
      return GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 이메일 인증 / 비밀번호 재설정
  // ---------------------------------------------------------------------------

  /// 비밀번호 재설정 메일 발송 (로그인 전에도 사용 가능)
  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: _normalizeEmail(email));

  /// 인증 메일 (재)발송. 너무 자주 누르면 too-many-requests
  static Future<void> sendEmailVerification() async {
    final u = user;
    if (u == null) throw const ApiException('로그인이 필요해요');
    await u.sendEmailVerification();
  }

  /// 서버에서 최신 상태를 다시 읽고 인증 완료 여부를 반환
  /// ("인증했어요" 버튼을 눌렀을 때 호출)
  static Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ---------------------------------------------------------------------------
  // 계정 관리
  // ---------------------------------------------------------------------------

  /// 서버에서 최신 계정 정보 다시 읽기
  static Future<void> reload() async => user?.reload();

  /// 표시 이름 변경
  static Future<void> updateDisplayName(String name) async {
    final u = user;
    if (u == null) throw const ApiException('로그인이 필요해요');
    await u.updateDisplayName(name.trim());
    await u.reload();
  }

  /// 민감한 작업(비밀번호 변경, 계정 삭제) 전 본인 재확인.
  /// 이메일 계정은 [password] 필요, 구글 계정은 로그인 창이 다시 뜹니다.
  static Future<void> reauthenticate({String? password}) async {
    final u = user;
    if (u == null) throw const ApiException('로그인이 필요해요');

    if (isPasswordUser) {
      if (password == null || password.isEmpty) {
        throw const ApiException('비밀번호를 입력해주세요');
      }
      await u.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: u.email!, password: password),
      );
    } else if (isGoogleUser) {
      if (kIsWeb) {
        await u.reauthenticateWithPopup(GoogleAuthProvider());
        return;
      }
      final c = await _googleCredential();
      if (c == null) throw const ApiException('본인 확인이 취소됐어요');
      await u.reauthenticateWithCredential(c);
    } else {
      throw const ApiException('지원하지 않는 로그인 방식이에요');
    }
  }

  /// 비밀번호 변경 (이메일 계정만, 현재 비밀번호 확인 후)
  static Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (!isPasswordUser) {
      throw const ApiException('구글 계정은 비밀번호를 변경할 수 없어요');
    }
    await reauthenticate(password: currentPassword);
    await user!.updatePassword(newPassword);
  }

  // ---------------------------------------------------------------------------
  // 에러 문구
  // ---------------------------------------------------------------------------

  /// 예외 -> 사용자에게 보여줄 한국어 문구
  static String errorMessage(Object e) {
    if (e is ApiException) return e.message;
    if (e is GoogleSignInException) {
      return '구글 로그인에 실패했어요. 설정(SHA-1, 클라이언트 ID)을 확인해주세요';
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return '이메일 형식이 올바르지 않아요';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-mismatch':
          return '이메일 또는 비밀번호가 맞지 않아요';
        case 'email-already-in-use':
          return '이미 가입된 이메일이에요 (구글로 가입했다면 구글 로그인을 이용해주세요)';
        case 'account-exists-with-different-credential':
          return '이미 다른 방법으로 가입된 이메일이에요';
        case 'credential-already-in-use':
          return '이미 다른 계정에 연결된 로그인 정보예요';
        case 'weak-password':
          return '비밀번호가 너무 약해요';
        case 'user-disabled':
          return '사용이 중지된 계정이에요';
        case 'requires-recent-login':
          return '보안을 위해 다시 로그인한 뒤 시도해주세요';
        case 'operation-not-allowed':
          return '이 로그인 방식이 꺼져 있어요 (Firebase 콘솔 설정 확인)';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요';
        case 'too-many-requests':
          return '시도가 너무 많아요. 잠시 후 다시 해주세요';
        default:
          return e.message ?? '인증 중 오류가 발생했어요';
      }
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return '접근 권한이 없어요 (Firestore 보안 규칙 확인)';
        case 'unavailable':
          return '서버에 연결할 수 없어요. 네트워크를 확인해주세요';
        default:
          return e.message ?? '데이터 처리 중 오류가 발생했어요';
      }
    }
    return '알 수 없는 오류가 발생했어요';
  }
}
