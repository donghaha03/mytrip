/// 소셜 로그인 설정값
class SocialConfig {
  SocialConfig._();

  /// 구글 "웹 클라이언트 ID" (xxxx.apps.googleusercontent.com)
  /// Firebase 콘솔 → Authentication → Sign-in method → Google → 웹 SDK 구성
  /// 비워두면 google-services.json 설정을 그대로 사용합니다.
  static const googleServerClientId =
      '600150474690-6ve4oich2faph02ppn7l9sj5nct9fanl.apps.googleusercontent.com';
  static const kakaoServerUrl = 'https://triper-l8ty.onrender.com';
}
