import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';

/// 10. 로그인 / 회원가입.
///
/// ───────────────────────────────────────────────────────────────
///  이 파일은 "로그인 페이지" 담당자 것이다. 다른 사람은 건드리지 않는다.
///  (담당 표는 CONTRIBUTING.md 참고)
/// ───────────────────────────────────────────────────────────────
///
/// 앱이 로그인 없이는 안 넘어가서 일단 "돌아가기만 하는" 폼을 넣어 뒀다.
/// 디자인·문구·구성은 전부 갈아엎어도 된다. 지켜야 할 건 하나:
///
///   authService.signIn(email, password)   // 로그인
///   authService.signUp(email, password)   // 회원가입
///
/// 를 부르고, 실패하면 던져지는 AuthException 의 message 를 보여줄 것.
/// 성공 후 화면 이동은 main.dart 의 AuthGate 가 알아서 한다 —
/// 여기서 Navigator.push 하지 말 것.
///
/// 로컬 임시 모드에서는 아무 이메일 + 6자 이상 비밀번호로 통과한다.
/// Firebase 모드 규칙과 에러 문구를 똑같이 맞춰 뒀으니 여기서 만든 화면이
/// Firebase 에 붙여도 그대로 동작한다.
///
/// 추가로 만들 만한 것: 비밀번호 찾기, 비밀번호 확인 칸, 구글 로그인.
/// 인터페이스(AuthService)에 메서드를 더해야 하면 공용 파일이니 팀에 먼저 공유.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await authService.signUp(_email.text, _password.text);
      } else {
        await authService.signIn(_email.text, _password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.send_rounded,
                    size: 44, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text(
                  '여행 장부',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignUp ? '계정을 만들어 주세요' : '로그인하고 여행을 기록하세요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!Backend.isFirebase) ...[
                  const SizedBox(height: 16),
                  const _LocalModeBadge(),
                ],
                const SizedBox(height: 28),
                _field(_email, '이메일',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field(_password, '비밀번호 (6자 이상)', obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : Text(
                          _isSignUp ? '회원가입' : '로그인',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                          }),
                  child: Text(
                    _isSignUp ? '이미 계정이 있어요 · 로그인' : '처음이에요 · 회원가입',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboardType,
      cursorColor: AppColors.primary,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

/// naite-reservation 의 "임시 저장 모드" 안내와 같은 역할.
class _LocalModeBadge extends StatelessWidget {
  const _LocalModeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '로컬 임시 모드 — Firebase 설정 전이라 아무 이메일 + 6자 이상 비밀번호로 들어가져요. 데이터는 새로고침하면 사라져요.',
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
