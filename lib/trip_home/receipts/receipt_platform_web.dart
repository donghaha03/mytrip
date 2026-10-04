import 'dart:js_interop';

@JS('mytripReceipt.open')
external JSPromise<JSAny?> _open();
@JS('mytripReceipt.close')
external void closeReceiptCamera();
Future<String?> openReceiptCamera() async {
  final result = await _open().toDart;
  return (result as JSString?)?.toDart;
}
