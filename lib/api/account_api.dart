import 'auth_api.dart';
import 'trip_api.dart';

/// 여러 API를 조합하는 계정 작업
class AccountApi {
  AccountApi._();

  /// 회원 탈퇴: 본인 재확인 → 내 모든 여행/지출 삭제 → 계정 삭제
  /// - 이메일 계정: [password] 필요
  /// - 구글 계정: [password] 없이 호출 (로그인 창이 다시 뜸)
  /// (재확인을 먼저 해서, 확인에 실패했을 때 데이터만 지워지는 일을 막음)
  static Future<void> deleteAccount({String? password}) async {
    await AuthApi.reauthenticate(password: password);
    await TripApi.deleteAll();
    await AuthApi.user!.delete();
  }
}
