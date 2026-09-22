// Firebase 연결 설정. (참고한 naite-reservation 의 config.js 에 해당)
//
// 지금은 비어 있어서 앱이 "로컬 임시 모드" 로 뜬다 — 데이터는 메모리에만
// 있고, 로그인은 아무 이메일 + 6자 이상 비밀번호면 통과한다.
// 조원들은 이 상태 그대로 작업하면 된다.
//
// 실제 Firebase 에 붙이려면 (팀장이 한 번만):
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<firebase 프로젝트 id>
// 이 파일이 같은 모양으로 덮어써지고, 다음 실행부터 자동으로 Firebase 모드가 된다.
// 콘솔의 "웹 앱 설정" 값을 아래 web: 에 직접 붙여 넣어도 된다.
//
// 웹 API 키는 비밀번호가 아니다 (공개 repo 에 올라가도 된다).
// 대신 firestore.rules 와 Auth 의 "승인된 도메인" 을 반드시 설정할 것.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions 가 $defaultTargetPlatform 용으로 설정되지 않았다.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    authDomain: '',
    storageBucket: '',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
    iosBundleId: 'com.example.tripapp',
  );
}
