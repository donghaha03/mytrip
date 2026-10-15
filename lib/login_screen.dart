

import 'package:flutter/material.dart';
import 'api/api.dart';

import 'password_reset_screen.dart';

import 'signup_screen.dart';



class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});



  @override

  State<LoginScreen> createState() => _LoginScreenState();

}



class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController emailController =

      TextEditingController();

  final TextEditingController passwordController =

      TextEditingController();



  bool passwordVisible = false;

  bool isLoading = false;



  @override

  void dispose() {

    emailController.dispose();

    passwordController.dispose();

    super.dispose();

  }



  void _showMessage(String message) {

    if (!mounted) return;



    ScaffoldMessenger.of(context)

      ..hideCurrentSnackBar()

      ..showSnackBar(

        SnackBar(

          content: Text(message),

          duration: const Duration(seconds: 5),

        ),

      );

  }



  Future<void> _login() async {
    if (isLoading) return;
    final email = emailController.text.trim();
    final password = passwordController.text;
    final error = AuthApi.validateEmail(email) ?? AuthApi.validatePassword(password);
    if (error != null) {
      _showMessage(error);
      return;
    }
    setState(() => isLoading = true);
    try {
      await AuthApi.signIn(email, password);
      if (mounted) _showMessage('로그인 성공!');
    } catch (e) {
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _socialLogin(Future<bool> Function() authenticate, String message) async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      if (await authenticate() && mounted) _showMessage(message);
    } catch (e) {
      _showMessage(AuthApi.errorMessage(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _googleLogin() => _socialLogin(AuthApi.signInWithGoogle, 'Google 로그인 성공!');
  Future<void> _kakaoLogin() => _socialLogin(AuthApi.signInWithKakao, '카카오 로그인 성공!');
  Future<void> _naverLogin() => _socialLogin(AuthApi.authenticateWithNaver, '네이버 인증 성공!');

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F8FA),

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const SizedBox(height: 65),



              const Center(

                child: Column(

                  children: [

                    Text(

                      'TRIPER',

                      style: TextStyle(

                        fontSize: 34,

                        fontWeight: FontWeight.w800,

                        letterSpacing: 1.5,

                        color: Color(0xFF2F6FED),

                      ),

                    ),

                    SizedBox(height: 10),

                    Text(

                      '여행 예산을 더 쉽게',

                      style: TextStyle(

                        fontSize: 15,

                        color: Color(0xFF6B7280),

                      ),

                    ),

                  ],

                ),

              ),



              const SizedBox(height: 48),



              const Text(

                '로그인',

                style: TextStyle(

                  fontSize: 28,

                  fontWeight: FontWeight.w800,

                  color: Color(0xFF16181D),

                ),

              ),

              const SizedBox(height: 8),

              const Text(

                'TRIPER와 함께 여행을 시작해보세요.',

                style: TextStyle(

                  fontSize: 14,

                  color: Color(0xFF6B7280),

                ),

              ),



              const SizedBox(height: 28),



              const Text(

                '이메일',

                style: TextStyle(

                  fontSize: 14,

                  fontWeight: FontWeight.w600,

                ),

              ),

              const SizedBox(height: 9),



              TextField(

                controller: emailController,

                keyboardType: TextInputType.emailAddress,

                enabled: !isLoading,

                decoration: _inputDecoration(

                  '이메일을 입력해주세요',

                  Icons.email_outlined,

                ),

              ),



              const SizedBox(height: 18),



              const Text(

                '비밀번호',

                style: TextStyle(

                  fontSize: 14,

                  fontWeight: FontWeight.w600,

                ),

              ),

              const SizedBox(height: 9),



              TextField(

                controller: passwordController,

                obscureText: !passwordVisible,

                enabled: !isLoading,

                decoration: _inputDecoration(

                  '비밀번호를 입력해주세요',

                  Icons.lock_outline,

                ).copyWith(

                  suffixIcon: IconButton(

                    onPressed: () {

                      setState(() {

                        passwordVisible = !passwordVisible;

                      });

                    },

                    icon: Icon(

                      passwordVisible

                          ? Icons.visibility_outlined

                          : Icons.visibility_off_outlined,

                    ),

                  ),

                ),

              ),



              const SizedBox(height: 8),



              Align(

                alignment: Alignment.centerRight,

                child: TextButton(

                  onPressed: isLoading

                      ? null

                      : () {

                          Navigator.push(

                            context,

                            MaterialPageRoute(

                              builder: (_) =>

                                  const PasswordResetScreen(),

                            ),

                          );

                        },

                  child: const Text('비밀번호를 잊으셨나요?'),

                ),

              ),



              const SizedBox(height: 10),



              SizedBox(

                width: double.infinity,

                height: 52,

                child: ElevatedButton(

                  onPressed: isLoading ? null : _login,

                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFF2F6FED),

                    foregroundColor: Colors.white,

                    elevation: 0,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(12),

                    ),

                  ),

                  child: isLoading

                      ? const SizedBox(

                          width: 22,

                          height: 22,

                          child: CircularProgressIndicator(

                            color: Colors.white,

                            strokeWidth: 2.5,

                          ),

                        )

                      : const Text(

                          '로그인',

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.w700,

                          ),

                        ),

                ),

              ),



              const SizedBox(height: 16),



              Row(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  const Text(

                    '아직 계정이 없으신가요?',

                    style: TextStyle(

                      color: Color(0xFF6B7280),

                      fontSize: 13,

                    ),

                  ),

                  TextButton(

                    onPressed: isLoading

                        ? null

                        : () {

                            Navigator.push(

                              context,

                              MaterialPageRoute(

                                builder: (_) => const SignupScreen(),

                              ),

                            );

                          },

                    child: const Text(

                      '회원가입',

                      style: TextStyle(

                        color: Color(0xFF2F6FED),

                        fontWeight: FontWeight.w700,

                      ),

                    ),

                  ),

                ],

              ),



              const SizedBox(height: 16),



              Row(

                children: [

                  const Expanded(

                    child: Divider(color: Color(0xFFE5E7EB)),

                  ),

                  Padding(

                    padding: const EdgeInsets.symmetric(horizontal: 14),

                    child: Text(

                      '또는',

                      style: TextStyle(

                        color: Colors.grey.shade600,

                        fontSize: 12,

                      ),

                    ),

                  ),

                  const Expanded(

                    child: Divider(color: Color(0xFFE5E7EB)),

                  ),

                ],

              ),



              const SizedBox(height: 18),



              _SocialLoginButton(

                text: 'Google로 로그인',

                imagePath: 'assets/images/google_logo.png',

                onPressed: isLoading ? null : _googleLogin,

              ),



              const SizedBox(height: 12),



              _SocialLoginButton(

                text: '카카오로 로그인',

                imagePath: 'assets/images/kakao_logo.png',

                onPressed: isLoading ? null : _kakaoLogin,

              ),



              const SizedBox(height: 12),



              _NaverLoginButton(

                onPressed: isLoading ? null : _naverLogin,

              ),



              const SizedBox(height: 28),

            ],

          ),

        ),

      ),

    );

  }



  InputDecoration _inputDecoration(

    String hint,

    IconData icon,

  ) {

    return InputDecoration(

      hintText: hint,

      hintStyle: const TextStyle(

        color: Color(0xFF9EA6B3),

        fontSize: 14,

      ),

      prefixIcon: Icon(

        icon,

        color: const Color(0xFF6B7280),

      ),

      filled: true,

      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(

        horizontal: 16,

        vertical: 16,

      ),

      border: OutlineInputBorder(

        borderRadius: BorderRadius.circular(12),

        borderSide: const BorderSide(

          color: Color(0xFFE5E7EB),

        ),

      ),

      enabledBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(12),

        borderSide: const BorderSide(

          color: Color(0xFFE5E7EB),

        ),

      ),

      focusedBorder: OutlineInputBorder(

        borderRadius: BorderRadius.circular(12),

        borderSide: const BorderSide(

          color: Color(0xFF2F6FED),

          width: 1.5,

        ),

      ),

    );

  }

}



class _SocialLoginButton extends StatelessWidget {

  final String text;

  final String imagePath;

  final VoidCallback? onPressed;



  const _SocialLoginButton({

    required this.text,

    required this.imagePath,

    required this.onPressed,

  });



  @override

  Widget build(BuildContext context) {

    return SizedBox(

      width: double.infinity,

      height: 52,

      child: OutlinedButton(

        onPressed: onPressed,

        style: OutlinedButton.styleFrom(

          backgroundColor: Colors.white,

          foregroundColor: const Color(0xFF16181D),

          side: const BorderSide(color: Color(0xFFE5E7EB)),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(12),

          ),

        ),

        child: Row(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Image.asset(

              imagePath,

              width: 22,

              height: 22,

              fit: BoxFit.contain,

            ),

            const SizedBox(width: 10),

            Text(

              text,

              style: const TextStyle(

                fontSize: 14,

                fontWeight: FontWeight.w600,

              ),

            ),

          ],

        ),

      ),

    );

  }

}



class _NaverLoginButton extends StatelessWidget {

  final VoidCallback? onPressed;



  const _NaverLoginButton({

    required this.onPressed,

  });



  @override

  Widget build(BuildContext context) {

    return SizedBox(

      width: double.infinity,

      height: 52,

      child: OutlinedButton(

        onPressed: onPressed,

        style: OutlinedButton.styleFrom(

          backgroundColor: Colors.white,

          foregroundColor: const Color(0xFF16181D),

          side: const BorderSide(color: Color(0xFFE5E7EB)),

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(12),

          ),

        ),

        child: Row(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Container(

              width: 22,

              height: 22,

              alignment: Alignment.center,

              decoration: BoxDecoration(

                color: const Color(0xFF03C75A),

                borderRadius: BorderRadius.circular(4),

              ),

              child: const Text(

                'N',

                style: TextStyle(

                  color: Colors.white,

                  fontSize: 17,

                  fontWeight: FontWeight.w900,

                ),

              ),

            ),

            const SizedBox(width: 10),

            const Text(

              '네이버로 로그인',

              style: TextStyle(

                fontSize: 14,

                fontWeight: FontWeight.w600,

              ),

            ),

          ],

        ),

      ),

    );

  }

}
