import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart' show ApiException;
import 'receipt_result.dart';

/// 영수증 인식 중계 서버(Claude Haiku). 다른 서버로 바꾸려면 빌드할 때
/// `--dart-define=RECEIPT_SERVER_URL=https://...`를 넘긴다.
const ocrServerUrl = String.fromEnvironment(
  'RECEIPT_SERVER_URL',
  defaultValue: 'https://mytrip-receipt.mytrip-local-receipt.workers.dev',
);

/// 서버가 인정하는 동의 버전. 제공자나 전송 조건이 바뀌면 새 값으로 다시 동의받는다.
const ocrConsentVersion = 'claude-haiku-v1';

/// 사진이 JPEG·PNG·WebP이면 서버에 보낼 data URL을, 아니면 null을 돌려준다.
String? receiptDataUrl(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) =>
      bytes.length >= at + magic.length &&
      [for (var i = 0; i < magic.length; i++) bytes[at + i] == magic[i]]
          .every((same) => same);
  final type = starts([0xFF, 0xD8, 0xFF])
      ? 'jpeg'
      : starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
      ? 'png'
      : starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], 8)
      ? 'webp'
      : null;
  if (type == null) return null;
  final url = 'data:image/$type;base64,${base64Encode(bytes)}';
  return url.length > 12000000 ? null : url; // 서버 한도
}

/// 영수증 인식·품목 번역 호출. 실패하면 사용자에게 보여줄 문구가 담긴
/// [ApiException]을 던진다. 저장(Firestore)은 하지 않는다.
class OcrService {
  OcrService({http.Client? client, Uri? server})
    : _client = client ?? http.Client(),
      server = server ?? Uri.parse(ocrServerUrl);

  final http.Client _client;
  final Uri server;

  // 동의는 제공자·정책 버전·서버 주소별로 이 기기에만 저장한다.
  String get _consentKey =>
      'receipt_consent:$ocrConsentVersion:${server.origin}';

  /// true 동의함, false 거절함, null 아직 묻지 않음.
  Future<bool?> consent() async =>
      (await SharedPreferences.getInstance()).getBool(_consentKey);

  Future<void> setConsent(bool accepted) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _consentKey,
      accepted,
    );
    if (!saved) throw const ApiException('동의를 저장하지 못했어요. 다시 시도해주세요.');
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    if (await consent() != true) {
      throw const ApiException('사진 전송에 먼저 동의해주세요.');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            server.resolve(path),
            headers: {
              'Content-Type': 'application/json',
              'X-Receipt-Consent': ocrConsentVersion,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const ApiException('시간이 초과됐어요. 사진은 그대로예요. 다시 시도해주세요.');
    } catch (_) {
      throw const ApiException('서버에 연결하지 못했어요. 네트워크를 확인하고 다시 시도해주세요.');
    }
    if (response.statusCode != 200) {
      throw ApiException(switch (response.statusCode) {
        400 => '사진을 읽지 못했어요. 다른 사진으로 다시 시도해주세요.',
        401 => '사진 전송 동의를 확인해주세요.',
        403 => '이 주소에서는 영수증 서버를 쓸 수 없어요. 앱이나 허용된 웹 주소에서 열어주세요.',
        413 => '사진이 너무 커요. 다시 촬영해주세요.',
        429 => '사용 한도에 도달했어요. 잠시 후 다시 시도해주세요.',
        503 => '영수증 서버가 아직 준비되지 않았어요.',
        504 => '인식 시간이 초과됐어요. 다시 시도해주세요.',
        _ => '인식하지 못했어요. 다시 시도해주세요.',
      });
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('결과를 읽지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 영수증 사진 한 장을 인식한다.
  Future<OcrReceipt> recognize(Uint8List image) async {
    final dataUrl = receiptDataUrl(image);
    if (dataUrl == null) {
      throw const ApiException('JPEG·PNG·WebP 사진만 인식할 수 있어요. 다시 촬영해주세요.');
    }
    final data = await _post('/receipt/recognize', {'image': dataUrl});
    try {
      return OcrReceipt.fromDraft(data['draft']);
    } on FormatException {
      throw const ApiException('인식 결과를 읽지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 품목 이름만 보내 번역한다. [language]는 `ko` 또는 `en`.
  Future<List<String>> translate(List<String> names, String language) async {
    if (!['ko', 'en'].contains(language) ||
        names.isEmpty ||
        names.length > 100 ||
        names.any((name) => name.trim().isEmpty || name.length > 100)) {
      throw const ApiException('번역할 수 없는 품목 이름이 있어요.');
    }
    final data = await _post('/receipt/translate', {
      'names': names,
      'language': language,
    });
    final translated = data['names'];
    if (translated is! List ||
        translated.length != names.length ||
        translated.any(
          (name) => name is! String || name.trim().isEmpty || name.length > 300,
        )) {
      throw const ApiException('번역 결과를 읽지 못했어요. 원문은 그대로예요.');
    }
    return [for (final name in translated) (name as String).trim()];
  }

  void close() => _client.close();
}
