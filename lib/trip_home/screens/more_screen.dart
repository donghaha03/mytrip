import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../ledger/theme/app_colors.dart';
import '../../ledger/widgets/screen_top_bar.dart';

/// 더보기: 로그인한 계정과 로그아웃 (lib/api/how to use.md 5-8).
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late final _users = AuthApi.userChanges;
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    // 쌓여 있는 여행 화면을 먼저 닫는다. 로그인 화면으로의 전환은 AuthGate가 한다.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthApi.signOut();
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTopBar(title: '더보기'),
          StreamBuilder<User?>(
            stream: _users,
            builder: (context, _) => AuthApi.isLoggedIn
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthApi.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AuthApi.email ?? ''} · ${AuthApi.loginMethodLabel} 로그인',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          key: const ValueKey('more-sign-out'),
                          onPressed: _busy ? null : _signOut,
                          child: const Text('로그아웃'),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}
