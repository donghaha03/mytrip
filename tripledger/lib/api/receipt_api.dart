// [OCR] 영수증 OCR 기능 (feature/receipt-ocr)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt.dart';
import 'api_exception.dart';

/// 영수증 인식(OCR) API
/// - 앨범에서 사진을 고르고(pickPhoto), 인식 서버(중계 서버 -> Claude Haiku)로 보내 [Receipt]를 받는다
/// - 키·액세스 코드는 서버에만 있고 앱에는 없다
/// - 저장(Firestore)은 하지 않는다. 저장은 기존 ExpenseApi.add 그대로
class ReceiptApi {
  ReceiptApi._();

  static final Uri _server = Uri.parse(
    'https://mytrip-receipt.mytrip-local-receipt.workers.dev/receipt/recognize',
  );

  /// 서버가 확인하는 동의 버전. 전송 조건이 바뀌면 새 값으로 다시 동의받는다.
  static const String _consentVersion = 'claude-haiku-v1';
  static const String _consentKey = 'receipt_consent:$_consentVersion';

  // 아래 둘은 테스트에서 가짜 서버·가짜 사진을 끼울 때만 바꾼다.
  @visibleForTesting
  static http.Client client = http.Client();
  @visibleForTesting
  static Future<Uint8List?> Function()? pickPhotoForTest;

  /// 앨범에서 영수증 사진을 고른다. 취소하면 null. `image_picker` 패키지는 여기서만 쓴다.
  /// 앱 안 촬영은 ReceiptCamera(receipt_camera.dart)를 쓴다.
  static Future<Uint8List?> pickPhoto() async {
    final fake = pickPhotoForTest;
    if (fake != null) return fake();
    try {
      // 큰 사진은 줄여서 보낸다(서버 한도와 전송 시간).
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      return await file?.readAsBytes();
    } catch (_) {
      throw const ApiException('사진을 불러오지 못했어요. 사진 접근 권한을 확인해주세요.');
    }
  }

  /// 사진을 외부 서버로 보내는 데 동의했는지 (이 기기에 저장)
  static Future<bool> hasConsent() async =>
      (await SharedPreferences.getInstance()).getBool(_consentKey) ?? false;

  static Future<void> saveConsent() async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      _consentKey,
      true,
    );
    if (!saved) throw const ApiException('동의를 저장하지 못했어요. 다시 시도해주세요.');
  }

  /// 영수증 사진(JPEG·PNG·WebP) 한 장을 인식한다.
  /// 실패하면 사용자에게 보여줄 문구가 담긴 [ApiException]
  static Future<Receipt> scan(Uint8List image) async {
    if (!await hasConsent()) {
      throw const ApiException('사진 전송에 먼저 동의해주세요.');
    }

    final dataUrl = _dataUrl(image);
    if (dataUrl == null) {
      throw const ApiException('JPEG·PNG·WebP 사진만 인식할 수 있어요. 다른 사진으로 시도해주세요.');
    }

    final http.Response response;
    try {
      response = await client
          .post(
            _server,
            headers: {
              'Content-Type': 'application/json',
              'X-Receipt-Consent': _consentVersion,
            },
            body: jsonEncode({'image': dataUrl}),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const ApiException('시간이 초과됐어요. 다시 시도해주세요.');
    } catch (_) {
      throw const ApiException('서버에 연결하지 못했어요. 네트워크를 확인하고 다시 시도해주세요.');
    }

    if (response.statusCode != 200) {
      throw ApiException(switch (response.statusCode) {
        400 => '사진을 읽지 못했어요. 다른 사진으로 다시 시도해주세요.',
        401 => '사진 전송 동의를 확인해주세요.',
        403 => '이 주소에서는 영수증 인식을 쓸 수 없어요.',
        413 => '사진이 너무 커요. 다시 촬영해주세요.',
        429 => '사용 한도에 도달했어요. 잠시 후 다시 시도해주세요.',
        _ => '영수증을 인식하지 못했어요. 다시 시도해주세요.',
      });
    }

    const unreadable = ApiException('영수증 내용을 읽지 못했어요. 밝은 곳에서 다시 촬영해주세요.');
    final Receipt receipt;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      receipt = Receipt.fromJson(
        Map<String, dynamic>.from((body as Map)['draft'] as Map),
      );
    } catch (_) {
      throw unreadable;
    }
    // 가맹점도 금액도 못 읽었으면 채울 것이 없다.
    if (receipt.place.isEmpty &&
        receipt.amount == null &&
        receipt.unsupportedCurrency == null) {
      throw unreadable;
    }
    return receipt;
  }

  /// 서버에 보낼 data URL. JPEG·PNG·WebP가 아니거나 서버 한도(12MB)를 넘으면 null
  static String? _dataUrl(Uint8List bytes) {
    bool starts(List<int> magic, [int at = 0]) {
      if (bytes.length < at + magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[at + i] != magic[i]) return false;
      }
      return true;
    }

    final type = starts([0xFF, 0xD8, 0xFF])
        ? 'jpeg'
        : starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ? 'png'
        : starts([0x52, 0x49, 0x46, 0x46]) &&
              starts([0x57, 0x45, 0x42, 0x50], 8)
        ? 'webp'
        : null;
    if (type == null) return null;

    final url = 'data:image/$type;base64,${base64Encode(bytes)}';
    return url.length > 12000000 ? null : url;
  }
}
