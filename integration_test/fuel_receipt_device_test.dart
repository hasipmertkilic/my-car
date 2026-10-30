import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_car/features/insurance/services/document_ocr.dart';
import 'package:my_car/features/records/services/fuel_receipt_importer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android ML Kit fiş sütunlarından litre ve toplamı okur', (
    tester,
  ) async {
    final directory = await getExternalStorageDirectory();
    final file = File('${directory!.path}/mycar_receipt_test.png');
    final text = await recognizeDocumentImage(
      await file.readAsBytes(),
      receiptLayout: true,
    );
    final fields = parseFuelReceipt(text);
    // Only synthetic data is used. Do not log real receipts or raw OCR text.
    expect(fields.litersMilli, 42300, reason: 'Litre okunamadı');
    expect(
      fields.amountKurus,
      211500,
      reason: 'TOP/fiyat sütunları eşleştirilemedi',
    );
  });
}
