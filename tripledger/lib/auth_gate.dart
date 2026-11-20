import 'package:flutter/material.dart';

import 'api/api.dart';

import 'login_screen.dart';
import 'sign_up_screen.dart';
import 'verify_email_page.dart';
import 'homeshell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream _userChanges = AuthApi.userChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 로그인하지 않은 사용자
        if (snapshot.data == null) {
          return LoginScreen(
            onSignUp: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
            },
          );
        }

        // 로그인했지만 이메일 인증을 완료하지 않은 사용자
        if (AuthApi.needsEmailVerification) {
          return VerifyEmailPage(
            onVerified: () {
              setState(() {});
            },
          );
        }

        // 인증 완료 사용자
        return const HomeShell();
      },
    );
  }
}
