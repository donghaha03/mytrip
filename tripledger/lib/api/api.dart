// =============================================================================
// api.dart - 팀 공용 진입점. 화면 파일에서는 이 파일 하나만 import 하세요.
//   import '../api/api.dart';
//
// ┌ 로그인    AuthApi.signIn / signUp / signOut / sendPasswordReset
// │          AuthApi.signInWithGoogle (취소하면 false)
// │          AuthApi.initSocial (main에서 1회) / loginMethodLabel
// │          AuthApi.user / displayName / email / changes / errorMessage
// │          AuthApi.validateEmail / validatePassword / validateNewPassword
// │          AuthApi.validatePasswordMatch / validateName (폼 검증용)
// │          AuthApi.needsEmailVerification / checkEmailVerified (메일 인증)
// ├ 계정      AuthApi.updateDisplayName / changePassword / sendEmailVerification
// │          AccountApi.deleteAccount (회원 탈퇴: 데이터 + 계정 삭제)
// ├ 여행      TripApi.watchAll / watch / get / add / update / updateBudget / delete
// ├ 지출      ExpenseApi.watchAll / add / update / delete / restore
// ├ 환율      RateApi.load / krwPer / toKrw / fromKrw / lastFetched
// ├ 계산      LedgerCalc.spentKrw / remainingKrw / usedRatio / byCategory ...
// └ 표시      won() / localAmt() / dateShort() / dayOnly()
//
// 규칙: 화면(UI) 코드에서 Firestore를 직접 만지지 말고 여기 함수만 호출하세요.
// =============================================================================

export '../constants.dart';
export '../models/expense.dart';
export '../models/trip.dart';
export '../utils/format.dart';
export 'account_api.dart';
export 'api_exception.dart';
export 'auth_api.dart';
export 'expense_api.dart';
export 'ledger_calc.dart';
export 'rate_api.dart';
export 'trip_api.dart';
