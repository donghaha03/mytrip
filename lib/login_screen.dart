

import 'dart:convert';



import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:naver_login_flutter/naver_login_flutter.dart';

import 'package:http/http.dart' as http;



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



  static const String serverUrl =

      'https://triper-l8ty.onrender.com';



  static const String googleServerClientId =

      '600150474690-6ve4oich2faph02ppn7l9sj5nct9fanl.apps.googleusercontent.com';



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



  // 이메일 로그인

  Future<void> _login() async {

    if (isLoading) return;



    final email = emailController.text.trim();

    final password = passwordController.text;



    if (email.isEmpty || password.isEmpty) {

      _showMessage('이메일과 비밀번호를 입력해주세요.');

      return;

    }



    setState(() => isLoading = true);



    try {

      await FirebaseAuth.instance.signInWithEmailAndPassword(

        email: email,

        password: password,

      );



      if (!mounted) return;

      _showMessage('로그인 성공!');

    } on FirebaseAuthException catch (e) {

      debugPrint('이메일 로그인 오류: ${e.code} ${e.message}');



      if (!mounted) return;

      _showMessage('로그인 실패: ${e.message ?? e.code}');

    } catch (e) {

      debugPrint('이메일 로그인 오류: $e');



      if (!mounted) return;

      _showMessage('로그인 중 오류가 발생했습니다.');

    } finally {

      if (mounted) setState(() => isLoading = false);

    }

  }



  // Google 로그인

  Future<void> _googleLogin() async {

    if (isLoading) return;



    setState(() => isLoading = true);



    try {

      await GoogleSignIn.instance.initialize(

        serverClientId: googleServerClientId,

      );



      final GoogleSignInAccount account =

          await GoogleSignIn.instance.authenticate();



      final GoogleSignInAuthentication authentication =

          account.authentication;



      final String? idToken = authentication.idToken;



      if (idToken == null || idToken.isEmpty) {

        throw Exception('Google ID 토큰을 받지 못했습니다.');

      }



      final OAuthCredential credential =

          GoogleAuthProvider.credential(idToken: idToken);



      await FirebaseAuth.instance.signInWithCredential(credential);



      if (!mounted) return;

      _showMessage('Google 로그인 성공!');

    } on FirebaseAuthException catch (e) {

      debugPrint('Google Firebase 오류: ${e.code} ${e.message}');



      if (!mounted) return;

      _showMessage('Google 로그인 실패: ${e.message ?? e.code}');

    } on GoogleSignInException catch (e) {

      debugPrint('Google 로그인 오류: ${e.code} ${e.description}');



      if (!mounted) return;

      _showMessage('Google 로그인 실패: ${e.description ?? e.code}');

    } catch (e) {

      debugPrint('Google 로그인 오류: $e');



      if (!mounted) return;

      _showMessage('Google 로그인 중 오류가 발생했습니다.');

    } finally {

      if (mounted) setState(() => isLoading = false);

    }

  }



  // 카카오 로그인 → Render 서버 → Firebase

  Future<void> _kakaoLogin() async {

    if (isLoading) return;



    setState(() => isLoading = true);



    try {

      OAuthToken kakaoToken;



      if (await isKakaoTalkInstalled()) {

        try {

          kakaoToken =

              await UserApi.instance.loginWithKakaoTalk();

        } catch (e) {

          debugPrint('카카오톡 로그인 전환: $e');

          kakaoToken =

              await UserApi.instance.loginWithKakaoAccount();

        }

      } else {

        kakaoToken =

            await UserApi.instance.loginWithKakaoAccount();

      }



      final response = await http

          .post(

            Uri.parse('$serverUrl/auth/kakao'),

            headers: {'Content-Type': 'application/json'},

            body: jsonEncode({

              'accessToken': kakaoToken.accessToken,

            }),

          )

          .timeout(const Duration(seconds: 60));



      debugPrint('카카오 서버 응답 코드: ${response.statusCode}');

      debugPrint('카카오 서버 응답: ${response.body}');



      if (response.statusCode != 200) {

        throw Exception(

          '카카오 서버 인증 실패: ${response.statusCode}',

        );

      }



      final Map<String, dynamic> data =

          jsonDecode(response.body) as Map<String, dynamic>;



      final String? customToken =

          data['customToken'] as String?;



      if (customToken == null || customToken.isEmpty) {

        throw Exception('Firebase 인증 토큰을 받지 못했습니다.');

      }



      await FirebaseAuth.instance.signInWithCustomToken(customToken);



      if (!mounted) return;

      _showMessage('카카오 로그인 성공!');

    } on FirebaseAuthException catch (e) {

      debugPrint('카카오 Firebase 오류: ${e.code} ${e.message}');



      if (!mounted) return;

      _showMessage('카카오 로그인 실패: ${e.message ?? e.code}');

    } catch (e) {

      debugPrint('카카오 로그인 오류: $e');



      if (!mounted) return;

      _showMessage('카카오 로그인 실패: $e');

    } finally {

      if (mounted) setState(() => isLoading = false);

    }

  }



  // 네이버 로그인 진단
  // 현재는 네이버 인증 및 토큰 수신까지 확인합니다.
  // Render 서버/Firebase 연동은 다음 단계에서 연결합니다.
  Future<void> _naverLogin() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      debugPrint('===== 네이버 로그인 시작 =====');

      final NaverLoginResult result = await FlutterNaverLogin.logIn();

      debugPrint('네이버 로그인 상태: ${result.status}');
      debugPrint('네이버 계정 정보 수신 여부: ${result.account != null}');
      debugPrint('네이버 토큰 수신 여부: ${result.accessToken != null}');

      if (result.status != NaverLoginStatus.loggedIn) {
        final message = result.errorMessage ?? result.status.toString();
        debugPrint('네이버 로그인 실패 또는 취소: $message');
        if (!mounted) return;
        _showMessage('네이버 로그인 실패: $message');
        return;
      }

      final NaverToken? token = result.accessToken;
      if (token == null || !token.isValid() || token.accessToken.isEmpty) {
        throw Exception('유효한 네이버 액세스 토큰을 받지 못했습니다.');
      }

      debugPrint('네이버 인증 성공');
      debugPrint('네이버 액세스 토큰 수신 여부: ${token.accessToken.isNotEmpty}');

      if (!mounted) return;
      _showMessage('네이버 인증 성공! 서버 연결은 다음 단계에서 확인합니다.');
    } catch (e, stackTrace) {
      debugPrint('===== 네이버 로그인 오류 =====');
      debugPrint('오류 내용: $e');
      debugPrint('오류 위치: $stackTrace');
      if (!mounted) return;
      _showMessage('네이버 로그인 오류: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

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
