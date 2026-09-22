import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

enum BackendMode {
  /// Firebase 설정이 없다. 데이터는 메모리에만, 로그인은 가짜.
  local,

  /// Firebase Auth + Firestore 에 붙었다.
  firebase,
}

/// 앱이 어느 모드로 떴는지.
///
/// naite-reservation 의 store.js 와 같은 방식이다 — 설정이 있으면 붙고,
/// 없거나 붙다가 실패하면 조용히 로컬 임시 모드로 뜬다. 덕분에 조원들은
/// Firebase 키 없이도 clone 하자마자 `flutter run` 이 된다.
class Backend {
  Backend._();

  static BackendMode mode = BackendMode.local;
  static bool get isFirebase => mode == BackendMode.firebase;

  /// 키가 있어도 강제로 로컬 모드로 띄운다. Firebase 콘솔 설정이 덜 됐거나
  /// 오프라인에서 화면만 만질 때:
  ///   flutter run -d chrome --dart-define=LOCAL_MODE=true
  static const _forceLocal = bool.fromEnvironment('LOCAL_MODE');

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
