import 'package:flutter/material.dart';

import 'api/api.dart';
import 'login_screen.dart';

/// 로그인 여부에 따라 화면을 나눈다 (lib/api/how to use.md 1-4).
/// 로그인/로그아웃 뒤의 화면 전환은 여기서만 하고, 화면에서 직접 이동하지 않는다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.home, this.userChanges});

  /// 로그인한 사용자에게 보여줄 화면. 사용자가 바뀌면 새로 만든다.
  final Widget home;
  final Stream<User?>? userChanges;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _users = widget.userChanges ?? AuthApi.userChanges;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _users,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(child: Text(AuthApi.errorMessage(snapshot.error!))),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      return user == null
          ? const LoginScreen()
          : KeyedSubtree(key: ValueKey(user.uid), child: widget.home);
    },
  );
}
