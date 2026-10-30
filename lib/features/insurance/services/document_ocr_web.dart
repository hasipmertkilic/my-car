import 'dart:js_interop';
import 'dart:typed_data';

@JS('myCarRecognizeDocument')
external JSPromise<JSString> _recognize(
  JSUint8Array bytes,
  JSBoolean receiptLayout,
  JSBoolean sparseText,
);
Future<String> recognizeDocumentImage(
  Uint8List bytes, {
  bool receiptLayout = false,
  bool sparseText = false,
}) async => (await _recognize(
  bytes.toJS,
  receiptLayout.toJS,
  sparseText.toJS,
).toDart).toDart;
