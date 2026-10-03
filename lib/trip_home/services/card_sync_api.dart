import 'dart:convert';

import 'package:http/http.dart' as http;

/// API 비밀키는 서버 전용. 카드사 로그인 정보는 인증 요청 때만 HTTPS로 전송한다.
class CardSyncApi {
  static const serverUrl = String.fromEnvironment('CARD_SERVER_URL');
  static bool get configured => serverUrl.isNotEmpty;

  static const consentVersion = '2026-10-04';
  static const issuers = {'0303': '삼성카드', '0306': '신한카드'};

  static Future<Map<String, dynamic>> connection({
    required String action,
    String? tripId,
    required String idToken,
    Map<String, Object> fields = const {},
    http.Client? client,
    Uri? base,
  }) {
    if (!['status', 'authenticate', 'select', 'disconnect'].contains(action)) {
      throw ArgumentError('지원하지 않는 카드 연결 요청');
    }
    return _post(
      Uri.parse(
        '${(base?.toString() ?? serverUrl).replaceFirst(RegExp(r'/+$'), '')}/connection/$action',
      ),
      {'tripId': ?tripId, ...fields},
      idToken,
      client,
      action == 'authenticate'
          ? const Duration(minutes: 11)
          : const Duration(minutes: 6),
    );
  }

  static Future<({int received, int skipped})> synchronize({
    required String tripId,
    required String idToken,
    http.Client? client,
    Uri? endpoint,
  }) async {
    final url =
        endpoint ??
        Uri.parse('${serverUrl.replaceFirst(RegExp(r'/+$'), '')}/sync');
    final data = await _post(
      url,
      {'tripId': tripId},
      idToken,
      client,
      const Duration(minutes: 6),
    );
    if (data['received'] is! int ||
        data['skipped'] is! int ||
        data['received'] < 0 ||
        data['skipped'] < 0) {
      throw const FormatException('올바르지 않은 동기화 응답');
    }
    return (received: data['received'] as int, skipped: data['skipped'] as int);
  }

  static Future<Map<String, dynamic>> _post(
    Uri url,
    Map<String, Object> payload,
    String idToken,
    http.Client? client,
    Duration timeout,
  ) async {
    if (idToken.isEmpty) throw StateError('로그인이 필요해요');
    if (!url.hasAuthority ||
        url.userInfo.isNotEmpty ||
        (url.scheme != 'https' &&
            !(url.scheme == 'http' &&
                ['127.0.0.1', 'localhost'].contains(url.host)))) {
      throw StateError('안전한 카드 연동 서버가 필요해요');
    }
    final headers = {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode(payload);
    final response =
        await (client?.post(url, headers: headers, body: body) ??
                http.post(url, headers: headers, body: body))
            .timeout(timeout);
    if (response.statusCode == 401) throw StateError('다시 로그인해주세요');
    if (response.statusCode == 403) {
      throw StateError('운영자가 승인한 테스트 계정만 연결할 수 있어요');
    }
    if (response.statusCode == 404) throw StateError('로그인한 계정의 여행을 먼저 선택해주세요');
    if (response.statusCode == 409) {
      throw StateError('연결 상태나 여행 기간을 확인해주세요. 기존 연결 해제 후 다시 시도해주세요.');
    }
    if (response.statusCode == 422) {
      throw StateError(
        '카드사 인증 또는 보유카드를 확인하지 못했어요. 반복 입력하지 말고 카드사에서 먼저 확인해주세요.',
      );
    }
    if (response.statusCode == 423) {
      throw StateError('인증 시도를 중단했어요. 카드사 비밀번호 확인 후 서버 운영자에게 문의해주세요.');
    }
    if (response.statusCode == 429) throw StateError('조회 대기 중이에요. 잠시 후 확인해주세요');
    if (response.statusCode == 503) throw StateError('연동 서버의 CODEF 설정이 필요해요');
    if (response.statusCode != 200) throw StateError('카드 내역을 불러오지 못했어요');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('올바르지 않은 카드 연결 응답');
    }
    return data;
  }
}
