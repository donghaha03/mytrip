import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const receiptChannel = MethodChannel('mytrip/receipt');

Future<String?> openReceiptCamera() {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return Future.error(
      UnsupportedError('이 기기에서는 영수증 촬영을 지원하지 않아요. 수동으로 입력해주세요.'),
    );
  }
  return receiptChannel.invokeMethod<String>('open');
}

void closeReceiptCamera() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    unawaited(
      receiptChannel.invokeMethod<void>('close').catchError((Object _) {}),
    );
  }
}
