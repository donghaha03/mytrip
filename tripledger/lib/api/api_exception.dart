/// API에서 사용자에게 보여줄 메시지가 있는 예외
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
