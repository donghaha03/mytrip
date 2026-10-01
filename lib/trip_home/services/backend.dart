import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

enum BackendMode {
  /// Firebase 설정이 없다. 데이터는 메모리에만, 로그인은 가짜.
  local,

  /// Firebase Auth + Firestore 에 붙었다.
  firebase,
}

/// 기본은 샘플 데이터로 화면만 확인하는 로컬 모드다.
class Backend {
  Backend._();

  static BackendMode mode = BackendMode.local;
  static bool get isFirebase => mode == BackendMode.firebase;

  /// Firebase를 명시적으로 사용할 때만 LOCAL_MODE=false로 실행한다.
  static const _forceLocal = bool.fromEnvironment(
    'LOCAL_MODE',
    defaultValue: true,
  );

  static Future<BackendMode> init() async {
    if (_forceLocal) return mode = BackendMode.local;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options.apiKey.isEmpty || options.projectId.isEmpty) {
        return mode = BackendMode.local;
      }
      await Firebase.initializeApp(options: options);
      return mode = BackendMode.firebase;
    } catch (e) {
      // 설정은 있는데 초기화가 실패한 경우 (키 오타, 네트워크 등).
      // 화면이 하얗게 죽는 것보다 로컬로라도 뜨는 게 낫다.
      debugPrint('[Backend] Firebase 초기화 실패 -> 로컬 임시 모드: $e');
      return mode = BackendMode.local;
    }
  }
}
