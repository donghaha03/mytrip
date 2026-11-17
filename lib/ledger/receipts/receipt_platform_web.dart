import 'dart:js_interop';

@JS('mytripReceipt.open')
external JSPromise<JSAny?> _open(JSBoolean captureOnly, JSString source);
@JS('mytripReceipt.connection')
external JSString? _connection();
@JS('mytripReceipt.close')
external void closeReceiptCamera();
String? getReceiptRuntime() => _connection()?.toDart;
Uri get receiptConfigUrl => Uri.base.resolve('receipt-config.json');
Future<void> recoverReceiptCamera() async {}
Future<String?> openReceiptCamera({
  bool captureOnly = false,
  bool gallery = false,
}) async {
  final result = await _open(
    captureOnly.toJS,
    (gallery ? 'gallery' : 'camera').toJS,
  ).toDart;
  return (result as JSString?)?.toDart;
}
