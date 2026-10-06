import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'receipt_draft.dart';

class ReceiptConnection {
  const ReceiptConnection(this.url, {this.csrf});
  final Uri url;
  final String? csrf;
  bool get needsAccessCode => csrf == null;
}

class ReceiptConnectionException implements Exception {
  const ReceiptConnectionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Every supported platform uses this client after the user confirms the photo.
class ReceiptClient {
  ReceiptClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  bool _busy = false;

  Future<ReceiptConnection?> connection({
    String? localRuntime,
    String serverUrl = const String.fromEnvironment('RECEIPT_SERVER_URL'),
    required Uri configUrl,
  }) async {
    // A compiled server address wins, so all builds can target the same backend.
    if (serverUrl.isNotEmpty) return _remote(serverUrl);
    if (localRuntime != null) {
      final data = jsonDecode(localRuntime) as Map<String, dynamic>;
      final url = Uri.parse(data['url'] as String);
      if (url.scheme != 'http' ||
          url.host != '127.0.0.1' ||
          url.path != '/receipt/recognize' ||
          data['csrf'] is! String) {
        throw const ReceiptConnectionException('로컬 영수증 연결을 확인해주세요.');
      }
      return ReceiptConnection(url, csrf: data['csrf'] as String);
    }
    try {
      final response = await _client
          .get(configUrl)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw const FormatException();
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!data.containsKey('serverUrl')) throw const FormatException();
      final url = data['serverUrl'];
      if (url == null) {
        return null; // Explicitly unconfigured; keep the existing device path.
      }
      if (url is! String) throw const FormatException();
      return _remote(url);
    } on ReceiptConnectionException {
      rethrow;
    } catch (_) {
      throw const ReceiptConnectionException(
        '영수증 서버 설정을 불러오지 못했어요. 연결을 확인하고 다시 시도해주세요.',
      );
    }
  }

  ReceiptConnection _remote(String value) {
    final url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        (url.path.isNotEmpty && url.path != '/')) {
      throw const ReceiptConnectionException(
        '영수증 서버 주소가 올바르지 않아요. 관리자에게 확인해주세요.',
      );
    }
    return ReceiptConnection(url.resolve('/receipt/recognize'));
  }

  Future<ReceiptDraft> recognize(
    ReceiptConnection connection,
    String image, {
    String accessCode = '',
  }) async {
    if (_busy) {
      throw const ReceiptConnectionException('영수증을 인식하고 있어요. 잠시 기다려주세요.');
    }
    if (!RegExp(
          r'^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/]+={0,2}$',
        ).hasMatch(image) ||
        image.length > 12000000) {
      throw const ReceiptConnectionException('사진을 읽지 못했어요. 다시 촬영해주세요.');
    }
    if (connection.needsAccessCode &&
        !RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(accessCode)) {
      throw const ReceiptConnectionException(
        '서버 관리자가 공유한 접속 코드를 입력해주세요. API 키를 입력하지 마세요.',
      );
    }
    _busy = true;
    try {
      final response = await _client
          .post(
            connection.url,
            headers: {
              'Content-Type': 'application/json',
              if (connection.csrf != null) 'X-mytrip-csrf': connection.csrf!,
              if (connection.needsAccessCode)
                'Authorization': 'Bearer $accessCode',
            },
            body: jsonEncode({'image': image}),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        throw ReceiptConnectionException(switch (response.statusCode) {
          401 => '접속 코드를 확인해주세요.',
          403 => '영수증 서버의 연결 권한을 확인해주세요.',
          413 => '사진이 너무 커요. 다시 촬영해주세요.',
          429 => '인식 요청이 많거나 사용 한도에 도달했어요. 잠시 후 다시 시도해주세요.',
          504 => '인식 시간이 초과됐어요. 다시 시도하거나 수동으로 입력해주세요.',
          _ => '인식하지 못했어요. 서버 연결·로그인·사용 한도를 확인하고 다시 시도해주세요.',
        });
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (data['draft'] is! Map<String, dynamic>) throw const FormatException();
      final draft = data['draft'] as Map<String, dynamic>;
      if (![
            'merchant',
            'date',
            'currency',
            'amount',
            'items',
            'warnings',
          ].every(draft.containsKey) ||
          draft['items'] is! List ||
          draft['warnings'] is! List) {
        throw const FormatException();
      }
      return ReceiptDraft.fromLlm(draft);
    } on ReceiptConnectionException {
      rethrow;
    } on TimeoutException {
      throw const ReceiptConnectionException(
        '인식 시간이 초과됐어요. 사진은 그대로예요. 다시 시도하거나 수동으로 입력해주세요.',
      );
    } on FormatException {
      throw const ReceiptConnectionException(
        '인식 결과를 읽지 못했어요. 다시 시도하거나 수동으로 입력해주세요.',
      );
    } catch (_) {
      throw const ReceiptConnectionException(
        '서버에 연결하지 못했어요. 네트워크를 확인하고 다시 시도해주세요.',
      );
    } finally {
      _busy = false;
    }
  }

  void close() => _client.close();
}
