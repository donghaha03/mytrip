import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'api/api.dart' show AuthApi;
import 'firebase_options.dart';
import 'ledger/data/rates.dart' as ledger;
import 'ledger/receipts/receipt_platform.dart';
import 'ledger/theme/app_theme.dart';
import 'trip_home/app.dart';

/// 앱 시작 시 한 번: Firebase → 구글 로그인 준비 → 환율 (lib/api/how to use.md 1-3).
/// 로그인 여부에 따른 화면 분기는 [TripApp] 안의 AuthGate가 한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(recoverReceiptCamera().catchError((Object _) {}));
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // 흰 화면으로 멈추지 않게 이유를 보여준다.
    runApp(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('앱을 시작하지 못했어요. 네트워크를 확인한 뒤 다시 실행해주세요.'),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // 구글 로그인 준비가 실패해도(플랫폼 설정 누락 등) 이메일 로그인은 쓸 수 있어야 한다.
  try {
    await AuthApi.initSocial();
  } catch (_) {}

  runApp(const TripApp());
  // 화면을 먼저 띄우고 환율을 읽는다. 하루 한 번만 실제로 호출된다.
  unawaited(ledger.RateApi.load());
  AppLifecycleListener(onResume: () => unawaited(ledger.RateApi.load()));
}
