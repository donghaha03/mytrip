import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tripapp/AppColors.dart';

import 'api/api.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';

//flutter pub add PLUGIN_NAME
//flutterfire configure -> flutter rebuild
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthApi.initSocial();
  await RateApi.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Triper Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const AuthGate(),
    );
  }
}
