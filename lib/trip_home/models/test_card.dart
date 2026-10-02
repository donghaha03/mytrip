/// 개발 화면용 식별 정보. 인증·결제 정보는 받거나 저장하지 않는다.
class TestCard {
  const TestCard({
    required this.issuer,
    required this.kind,
    required this.nickname,
    this.lastFour = '',
  });

  final String issuer;
  final String kind;
  final String nickname;
  final String lastFour;

  // 임시 등록 선택지이며, 실제 API 지원 목록이 아니다.
  static const issuers = [
    '토스뱅크',
    'KB국민',
    '현대',
    '삼성',
    'NH농협',
    'BC',
    '신한',
    '우리',
    '롯데',
    '하나',
    '씨티',
    '전북',
    '광주',
    '수협',
    '제주',
    '기타',
  ];
  static const kinds = ['체크카드', '신용카드', '기타'];

  static String? nicknameError(String value) {
    if (value.trim().isEmpty || value.trim().length > 30) {
      return '별칭을 1~30자로 입력해주세요';
    }
    if (RegExp(r'(?:\d[ -]*){8,}').hasMatch(value)) {
      return '별칭에 카드번호나 개인정보를 넣지 마세요';
    }
    return null;
  }

  static String? lastFourError(String value) =>
      value.isEmpty || RegExp(r'^\d{4}$').hasMatch(value)
      ? null
      : '끝 4자리만 입력하거나 비워두세요';

  String? get validationError =>
      !issuers.contains(issuer) || !kinds.contains(kind)
      ? '카드사와 종류를 확인해주세요'
      : nicknameError(nickname) ?? lastFourError(lastFour);

  String get displayLabel =>
      '$issuer · $kind · $nickname${lastFour.isEmpty ? '' : ' · •••• $lastFour'}';
}
