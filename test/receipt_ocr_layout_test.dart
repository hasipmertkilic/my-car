import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/core/utils/receipt_ocr_layout.dart';
import 'package:my_car/features/records/services/fuel_receipt_importer.dart';

void main() {
  test(
    'Telefon OCR blokları satır konumuna göre eşleştirilir; KDV toplamla karışmaz',
    () {
      final text = receiptTextInReadingOrder(const [
        ReceiptOcrLine('MOTORİN 42,300 LT', 10, 10, 220, 20),
        ReceiptOcrLine('TOPKDV', 10, 80, 80, 20),
        ReceiptOcrLine('TOP', 10, 120, 60, 20),
        ReceiptOcrLine('KREDİ KARTI', 10, 170, 120, 20),
        // Native OCR may return the entire price column after the labels.
        ReceiptOcrLine('*352,50', 300, 81, 90, 20),
        ReceiptOcrLine('*2.115,00', 280, 114, 110, 30),
        ReceiptOcrLine('*2.115,00', 280, 170, 110, 20),
      ]);
      expect(text, contains('TOP *2.115,00'));
      expect(parseFuelReceipt(text).amountKurus, 211500);
      expect(parseFuelReceipt(text).litersMilli, 42300);
    },
  );
  test('Yakın ama farklı satırdaki rakamlar eşleştirilmez', () {
    final text = receiptTextInReadingOrder(const [
      ReceiptOcrLine('TOPLAM', 10, 100, 100, 15),
      ReceiptOcrLine('TOPKDV', 10, 125, 100, 15),
      ReceiptOcrLine('352,50', 300, 125, 90, 15),
    ]);
    expect(receiptPaymentAmount(text.toLowerCase().split('\n')), isNull);
  });
}
