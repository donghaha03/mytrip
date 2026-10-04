Future<String?> openReceiptCamera() => Future.error(
  UnsupportedError('현재 앱은 웹에서 영수증 촬영을 지원해요. HTTPS 웹 주소에서 열거나 수동으로 입력해주세요.'),
);
void closeReceiptCamera() {}
