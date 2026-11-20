import 'package:flutter/material.dart';

import '../api/api.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _busy = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // 인증 메일 재발송
  Future<void> _resendEmail() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await AuthApi.sendEmailVerification();

      if (!mounted) return;
      _showMessage('인증 메일을 다시 보냈습니다.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 인증 완료 여부 확인
  Future<void> _checkVerification() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final ok = await AuthApi.checkEmailVerified();

      if (!mounted) return;

      if (ok) {
        _showMessage('이메일 인증이 완료되었습니다!');
        widget.onVerified();
      } else {
        _showMessage('아직 이메일 인증이 완료되지 않았습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 다른 계정으로 로그인
  Future<void> _signOut() async {
    try {
      await AuthApi.signOut();
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 76,
                    color: Color(0xFF2F6FED),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    '이메일 인증이 필요합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    '가입한 이메일로 인증 링크를 보냈습니다.\n'
                    '메일함에서 인증을 완료한 후\n'
                    '아래 버튼을 눌러주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: Color(0xFF7B8494),
                    ),
                  ),

                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _checkVerification,
                      child: _busy
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('인증했어요'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _resendEmail,
                      child: const Text('인증 메일 다시 보내기'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('다른 계정으로 로그인'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
