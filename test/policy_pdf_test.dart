import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:my_car/features/insurance/services/policy_document_importer.dart';
import 'package:my_car/features/insurance/services/policy_document_parser.dart';

// Synthetic document: no real policy or personal data is used.
Uint8List fixturePdf() {
  const lines = [
    'Trafik Sigortasi',
    'Sigorta Sirketi: Test Sigorta',
    'Police No: TEST-1234',
    'Baslangic Tarihi: 19.10.2026',
    'Bitis Tarihi: 19.10.2027',
    'Toplam Brut Prim: 12500,50 TL',
  ];
  final stream =
      'BT /F1 14 Tf 40 750 Td ${lines.map((s) => '($s) Tj 0 -24 Td').join(' ')} ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  var result = '%PDF-1.4\n';
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(result.length);
    result += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = result.length;
  result += 'xref\n0 6\n0000000000 65535 f \n';
  for (final offset in offsets) {
    result += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  result += 'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return Uint8List.fromList(ascii.encode(result));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Gerçek PDF motoru sentetik poliçenin metin katmanını okur', () async {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    final text = await LocalPolicyDocumentImporter().readBytes(fixturePdf());
    final fields = parsePolicyDocument(text);
    expect(fields.company, 'Test Sigorta');
    expect(fields.number, 'TEST-1234');
    expect(fields.premiumKurus, 1250050);
    expect(fields.endDate, DateTime(2027, 10, 19));
  });
  test('Desteklenmeyen dosya ve büyük dosya reddedilir', () async {
    final importer = LocalPolicyDocumentImporter();
    await expectLater(
      importer.readBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<DocumentReadFailure>()),
    );
    await expectLater(
      importer.readBytes(Uint8List(LocalPolicyDocumentImporter.maxBytes + 1)),
      throwsA(isA<DocumentReadFailure>()),
    );
  });
}
