import 'package:flutter/material.dart';

import '../api/api.dart';

/// TRIPER 회원가입 화면.
///
/// 인증 및 입력 검증은 AuthApi에 위임합니다.
/// 회원가입 성공 후 화면 전환은 AuthGate(AuthApi.userChanges)가 처리합니다.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const Color _primary = Color(0xFF2F6FED);
  static const Color _background = Color(0xFFF6F7F9);
  static const Color _text = Color(0xFF172033);
  static const Color _muted = Color(0xFF7B8494);
  static const Color _line = Color(0xFFE5E9F0);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_busy) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      await AuthApi.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        name: _nameController.text.trim(),
      );

      if (!mounted) return;

      // 자동 로그인 상태 해제
      await AuthApi.signOut();

      if (!mounted) return;

      // 인증 안내 메시지
      final navigator = Navigator.of(context);

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          Future.delayed(const Duration(seconds: 3), () {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          });

          return const AlertDialog(
            title: Text('회원가입 완료'),
            content: Text(
              '이메일을 확인하여 인증해주세요.\n\n'
              '잠시 후 로그인 페이지로 돌아갑니다.',
            ),
          );
        },
      );

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF273247),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFAFBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: const TextStyle(
        color: _muted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: Color(0xFFADB5C2), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE05252)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE05252), width: 1.5),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _text,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _passwordVisibilityButton({
    required bool visible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: visible ? '비밀번호 숨기기' : '비밀번호 보기',
      onPressed: onPressed,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: _muted,
        size: 20,
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
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: _text,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _line),
                        fixedSize: const Size(44, 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flight_takeoff_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'TRIPER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '새로운 여행을 시작해볼까요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _text,
                      fontSize: 24,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '계정을 만들고 여행 경비를 간편하게 관리해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFEDF0F4)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF24324A)
                              .withValues(alpha: 0.055),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '회원 정보 입력',
                            style: TextStyle(
                              color: _text,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '아래 정보를 입력해 계정을 생성하세요.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 22),
                          _sectionLabel('이름'),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            validator: AuthApi.validateName,
                            decoration: _decoration(
                              label: '이름',
                              hint: '여행에서 사용할 이름',
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _sectionLabel('이메일'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            validator: AuthApi.validateEmail,
                            decoration: _decoration(
                              label: '이메일 주소',
                              hint: 'example@email.com',
                              icon: Icons.mail_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _sectionLabel('비밀번호'),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: AuthApi.validateNewPassword,
                            decoration: _decoration(
                              label: '비밀번호',
                              hint: '영문과 숫자를 포함해 8자 이상',
                              icon: Icons.lock_outline_rounded,
                              suffix: _passwordVisibilityButton(
                                visible: !_obscurePassword,
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _sectionLabel('비밀번호 확인'),
                          TextFormField(
                            controller: _passwordConfirmController,
                            obscureText: _obscurePasswordConfirm,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: AuthApi.validatePasswordMatch(
                              () => _passwordController.text,
                            ),
                            onFieldSubmitted: (_) => _signUp(),
                            decoration: _decoration(
                              label: '비밀번호 확인',
                              hint: '비밀번호를 한 번 더 입력하세요',
                              icon: Icons.lock_person_outlined,
                              suffix: _passwordVisibilityButton(
                                visible: !_obscurePasswordConfirm,
                                onPressed: () => setState(
                                  () => _obscurePasswordConfirm =
                                      !_obscurePasswordConfirm,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 15,
                                color: _muted,
                              ),
                              SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  '비밀번호는 영문과 숫자를 포함한 8자 이상으로 설정해주세요.',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _busy ? null : _signUp,
                              style: FilledButton.styleFrom(
                                backgroundColor: _primary,
                                disabledBackgroundColor: _primary.withValues(
                                  alpha: 0.55,
                                ),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _busy
                                  ? const SizedBox(
                                      width: 21,
                                      height: 21,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '계정 만들기',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '가입하면 TRIPER와 함께 여행 경비 관리를 시작할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
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
