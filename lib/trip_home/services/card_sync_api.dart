import 'dart:convert';

import 'package:http/http.dart' as http;

/// 인증 토큰만 서버에 전달한다. 제공자 비밀키와 카드 인증정보는 앱에 두지 않는다.
class CardSyncApi {
  static const serverUrl = String.fromEnvironment('CARD_SERVER_URL');
  static bool get configured => serverUrl.isNotEmpty;

  static Future<({int received, int skipped})> synchronize({
    required String tripId,
    required String idToken,
    http.Client? client,
    Uri? endpoint,
  }) async {
    if (idToken.isEmpty) throw StateError('로그인이 필요해요');
    final url = endpoint ?? Uri.parse('$serverUrl/sync');
    if (url.scheme != 'https' &&
        url.host != '127.0.0.1' &&
        url.host != 'localhost') {
      throw StateError('안전한 카드 연동 서버가 필요해요');
    }
    final headers = {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'tripId': tripId});
    final response =
        await (client?.post(url, headers: headers, body: body) ??
                http.post(url, headers: headers, body: body))
            .timeout(const Duration(seconds: 45));
    if (response.statusCode == 401) throw StateError('다시 로그인해주세요');
    if (response.statusCode == 409) throw StateError('서버에 인증된 카드 연결이 없어요');
    if (response.statusCode == 429) throw StateError('조회 대기 중이에요. 잠시 후 확인해주세요');
    if (response.statusCode != 200) throw StateError('카드 내역을 불러오지 못했어요');
    final data = jsonDecode(response.body);
    if (data is! Map ||
        data['received'] is! int ||
        data['skipped'] is! int ||
        data['received'] < 0 ||
        data['skipped'] < 0) {
      throw const FormatException('올바르지 않은 동기화 응답');
    }
    return (received: data['received'] as int, skipped: data['skipped'] as int);
  }
}
