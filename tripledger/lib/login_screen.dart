import 'package:flutter/material.dart';

import '../api/api.dart';

/// TRIPER 로그인 화면.
///
/// - 화면에서는 Firebase / Google SDK를 직접 호출하지 않습니다.
/// - 이메일 및 Google 인증은 AuthApi에 위임합니다.
/// - 회원가입 화면 연결은 onSignUp 콜백으로 외부에서 주입합니다.
/// - 카카오/네이버는 현재 API 가이드에서 지원하지 않으므로 안내만 표시합니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onSignUp});

  /// 기존 회원가입 화면으로 이동하는 콜백.
  final VoidCallback? onSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _background = Color(0xFFF6F7F9);
  static const Color _primary = Color(0xFF2F6FED);
  static const Color _textSecondary = Color(0xFF737D8E);
  static const Color _border = Color(0xFFE0E4EA);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      await AuthApi.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // 로그인 성공 후 화면 이동은 AuthGate가 처리합니다.
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      final ok = await AuthApi.signInWithGoogle();
      if (!ok) return; // 사용자가 로그인 창을 닫거나 취소한 경우
      // 성공 후 AuthGate가 인증 상태 변화를 감지합니다.
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordResetDialog(),
    );

    if (!mounted || email == null || email.isEmpty) return;

    setState(() => _busy = true);

    try {
      await AuthApi.sendPasswordReset(email);

      if (!mounted) return;
      _showMessage('비밀번호 재설정 메일을 보냈어요.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showUnsupportedProvider(String provider) {
    _showMessage('$provider 로그인은 현재 API에서 지원하지 않습니다.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA5ADBA), fontSize: 14),
      prefixIcon: Icon(icon, color: _textSecondary, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 2),
                  const Text(
                    'TRIPER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '여행 예산을 더 쉽게',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 54),

                  const Text(
                    '로그인',
                    style: TextStyle(
                      color: Color(0xFF17191D),
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TRIPER와 함께 여행을 시작해보세요.',
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '이메일',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: AuthApi.validateEmail,
                          decoration: _inputDecoration(
                            hint: '이메일을 입력해주세요',
                            icon: Icons.mail_outline,
                          ),
                        ),
                        const SizedBox(height: 19),
                        const Text(
                          '비밀번호',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: AuthApi.validatePassword,
                          onFieldSubmitted: (_) => _login(),
                          decoration: _inputDecoration(
                            hint: '비밀번호를 입력해주세요',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? '비밀번호 표시'
                                  : '비밀번호 숨기기',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF50545C),
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 13),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy ? null : _sendPasswordReset,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF526DA8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '비밀번호 잊으셨나요?',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        disabledBackgroundColor: _primary.withValues(
                          alpha: 0.5,
                        ),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '로그인',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '아직 계정이 없으신가요?',
                        style: TextStyle(color: _textSecondary, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: widget.onSignUp,
                        style: TextButton.styleFrom(
                          foregroundColor: _primary,
                          padding: const EdgeInsets.only(left: 8, right: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 17),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: _border, height: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '또는',
                          style: TextStyle(color: _textSecondary, fontSize: 13),
                        ),
                      ),
                      Expanded(child: Divider(color: _border, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _SocialLoginButton(
                    onPressed: _busy ? null : _googleLogin,
                    icon: const _GoogleMark(),
                    label: 'Google로 로그인',
                  ),
                  const SizedBox(height: 12),
                  _SocialLoginButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await AuthApi.signInWithKakao();
                            } catch (e) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(AuthApi.errorMessage(e)),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _busy = false);
                              }
                            }
                          },
                    icon: const _KakaoMark(),
                    label: '카카오로 로그인',
                  ),
                  const SizedBox(height: 12),
                  _SocialLoginButton(
                    onPressed: _busy
                        ? null
                        : () => _showUnsupportedProvider('네이버'),
                    icon: const _NaverMark(),
                    label: '네이버로 로그인',
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

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF202329),
          side: const BorderSide(color: Color(0xFFE0E4EA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_logo.png',
      width: 22,
      height: 22,
      fit: BoxFit.contain,
    );
  }
}

class _KakaoMark extends StatelessWidget {
  const _KakaoMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/kakao_logo.png',
      width: 22,
      height: 22,
      fit: BoxFit.contain,
    );
  }
}

class _NaverMark extends StatelessWidget {
  const _NaverMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF03C75A),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text(
        'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
} //네이버만 직접그리네 뭐야 이거

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog();

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  static const Color _primary = Color(0xFF2F6FED);
  static const Color _textSecondary = Color(0xFF737D8E);
  static const Color _border = Color(0xFFE0E4EA);

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '비밀번호 재설정',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17191D),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '가입한 이메일 주소를 입력하면\n비밀번호 재설정 링크를 보내드려요.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 23),

            const Text(
              '이메일',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 9),

            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '이메일을 입력해주세요',
                hintStyle: const TextStyle(
                  color: Color(0xFFA5ADBA),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.mail_outline,
                  color: _textSecondary,
                  size: 22,
                ),
                filled: true,
                fillColor: const Color(0xFFF6F7F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: _primary, width: 1.4),
                ),
              ),
            ),

            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 47,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 47,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context, _controller.text.trim());
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '재설정 메일 보내기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
