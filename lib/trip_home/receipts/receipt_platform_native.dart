import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const receiptChannel = MethodChannel('mytrip/receipt');

String? getReceiptRuntime() => null;
Uri get receiptConfigUrl =>
    Uri.parse('https://donghaha03.github.io/mytrip/receipt-config.json');
final _picker = ImagePicker();
Future<String?>? _recovered;
Future<void> recoverReceiptCamera() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    _recovered ??= _recover();
    await _recovered;
  }
}

Future<String?> _recover() async {
  final lost = await _picker.retrieveLostData();
  if (lost.exception != null) throw lost.exception!;
  return lost.files?.isNotEmpty == true ? _photo(lost.files!.first) : null;
}

Future<String> _photo(XFile file) async {
  if (await file.length() > 8500000) {
    throw const ReceiptPhotoException('사진이 너무 커요. 다시 촬영하거나 다른 사진을 선택해주세요.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > 8500000 || bytes.length < 12) {
    throw const ReceiptPhotoException('사진이 너무 커요. 다시 촬영하거나 다른 사진을 선택해주세요.');
  }
  final mime = bytes[0] == 0xff && bytes[1] == 0xd8
      ? 'jpeg'
      : bytes[0] == 0x89 && bytes[1] == 0x50
      ? 'png'
      : String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
            String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP'
      ? 'webp'
      : null;
  if (mime == null) {
    throw const ReceiptPhotoException('사진을 열지 못했어요. 다시 촬영하거나 다른 사진을 선택해주세요.');
  }
  return jsonEncode({
    'image': 'data:image/$mime;base64,${base64Encode(bytes)}',
  });
}

class ReceiptPhotoException implements Exception {
  const ReceiptPhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<String?> openReceiptCamera({
  bool captureOnly = false,
  bool gallery = false,
}) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return receiptChannel.invokeMethod<String>('open', {
      'captureOnly': captureOnly,
    });
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    String? recovered;
    try {
      await recoverReceiptCamera();
      recovered = await _recovered;
    } finally {
      _recovered = Future.value(null);
    }
    if (recovered != null) return recovered;
  }
  final file = await _picker.pickImage(
    source: defaultTargetPlatform == TargetPlatform.android && !gallery
        ? ImageSource.camera
        : ImageSource.gallery,
    preferredCameraDevice: CameraDevice.rear,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 95,
    requestFullMetadata: false,
  );
  return file == null ? null : _photo(file);
}

void closeReceiptCamera() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    unawaited(
      receiptChannel.invokeMethod<void>('close').catchError((Object _) {}),
    );
  }
}
