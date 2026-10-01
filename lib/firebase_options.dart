// 개인 Firebase 프로젝트 설정. 기본 실행은 DB 연결 없는 화면 미리보기다.
// LOCAL_MODE=false일 때만 사용하며, 팀 통합 시 팀의 설정 파일을 유지한다.
// 웹 API 키와 별개로 Firestore 보안 규칙과 Auth 승인 도메인은 확인해야 한다.

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
    apiKey: 'AIzaSyDjEP2qqKagyRRRG0KHmtYLf-ytW_1PqbI',
    appId: '1:930702318741:web:939f8c0ced41df31784f9c',
    messagingSenderId: '930702318741',
    projectId: 'mytrip-fddfb',
    authDomain: 'mytrip-fddfb.firebaseapp.com',
    storageBucket: 'mytrip-fddfb.firebasestorage.app',
  );

  // 아직 Firebase 콘솔에 Android/iOS 앱을 등록하지 않았다. 비어 있으면
  // trip_home/services/backend.dart 가 로컬 임시 모드로 띄운다 (앱은 정상 동작하고
  // 데이터만 메모리에 남는다). 모바일에서도 Firestore 를 쓰려면 콘솔에서
  // 앱을 추가하고(패키지 이름 com.example.tripapp) 여기에 값을 채우면 된다.
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
