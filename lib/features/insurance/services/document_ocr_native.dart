import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/receipt_ocr_layout.dart';

Future<String> recognizeDocumentImage(
  Uint8List bytes, {
  bool receiptLayout = false,
  bool sparseText = false,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw UnsupportedError('Bu cihazda fotoğraftan okuma desteklenmiyor.');
  }
  final directory = await Directory(
    (await getTemporaryDirectory()).path,
  ).createTemp('policy_ocr_');
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final file = await File('${directory.path}/page.img').writeAsBytes(bytes);
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    if (!receiptLayout) return recognized.text;
    return receiptTextInReadingOrder([
      for (final block in recognized.blocks)
        for (final line in block.lines)
          ReceiptOcrLine(
            line.text,
            line.boundingBox.left,
            line.boundingBox.top,
            line.boundingBox.width,
            line.boundingBox.height,
          ),
    ]);
  } finally {
    await recognizer.close();
    await directory.delete(recursive: true);
  }
}
