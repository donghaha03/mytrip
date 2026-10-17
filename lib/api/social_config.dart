/// 소셜 로그인 설정값 (현재는 구글만 사용)
class SocialConfig {
  SocialConfig._();

  /// 구글 "웹 클라이언트 ID" (xxxx.apps.googleusercontent.com)
  /// Firebase 콘솔 → Authentication → Sign-in method → Google → 웹 SDK 구성
  /// 비워두면 google-services.json 설정을 그대로 사용합니다.
  static const googleServerClientId = '';
}
