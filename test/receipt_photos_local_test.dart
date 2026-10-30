import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/records/services/fuel_receipt_importer.dart';

void main() {
  const local = bool.fromEnvironment('CHECK_LOCAL_RECEIPTS');
  const newLocal = bool.fromEnvironment('CHECK_NEW_RECEIPTS');
  test(
    'Yeni KBENZİN ve bitişik LT fotoğrafları gerçek OCR sonucundan okunur',
    () {
      final texts =
          jsonDecode(
                File(
                  'build/receipt-validation-new/results.json',
                ).readAsStringSync(),
              )
              as List;
      const expected = [(23920, 100000), (44780, 15001)];
      for (var i = 0; i < expected.length; i++) {
        final source = texts[i] as Map;
        final first = parseFuelReceipt(source['prepared'] as String);
        final fields = first.litersMilli != null && first.amountKurus != null
            ? first
            : mergeFuelReceiptReadings(
                source['prepared'] as String,
                source['original'] as String,
              );
        expect(
          fields.litersMilli,
          expected[i].$1,
          reason: 'Yeni örnek ${i + 1}: litre',
        );
        expect(
          fields.amountKurus,
          expected[i].$2,
          reason: 'Yeni örnek ${i + 1}: tutar',
        );
      }
    },
    skip: !newLocal,
  );
  test('Kullanıcının üç yerel fotoğrafı gerçek OCR sonucundan okunur', () {
    final texts =
        jsonDecode(
              File('build/receipt-validation/results.json').readAsStringSync(),
            )
            as List;
    const expected = [(15520, 65029), (29900, 16505), (84150, 430974)];
    for (var i = 0; i < expected.length; i++) {
      final source = texts[i] as Map;
      final first = parseFuelReceipt(source['prepared'] as String);
      final fields = first.litersMilli != null && first.amountKurus != null
          ? first
          : mergeFuelReceiptReadings(
              source['prepared'] as String,
              source['original'] as String,
            );
      expect(
        fields.litersMilli,
        expected[i].$1,
        reason: 'Örnek ${i + 1}: litre',
      );
      expect(
        fields.amountKurus,
        expected[i].$2,
        reason: 'Örnek ${i + 1}: tutar',
      );
    }
  }, skip: !local);
}
