import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'document_ocr.dart';
import 'policy_document_parser.dart';

enum PolicyDocumentSource { file, camera }

class DocumentReadFailure implements Exception {
  const DocumentReadFailure(this.message);
  final String message;
}

abstract interface class PolicyDocumentImporter {
  Future<PolicyDocumentFields?> read(PolicyDocumentSource source);
}

class LocalPolicyDocumentImporter implements PolicyDocumentImporter {
  static const maxBytes = 20 * 1024 * 1024;
  @override
  Future<PolicyDocumentFields?> read(PolicyDocumentSource source) async {
    try {
      Uint8List bytes;
      if (source == PolicyDocumentSource.camera) {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          maxHeight: 3200,
          imageQuality: 95,
        );
        if (photo == null) return null;
        if (await photo.length() > maxBytes) {
          throw const DocumentReadFailure(
            'En fazla 20 MB büyüklüğünde belge seç.',
          );
        }
        bytes = await photo.readAsBytes();
      } else {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          dialogTitle: 'Poliçe belgesi seç',
        );
        if (file == null) return null;
        final length = await file.length();
        if (length == null || length > maxBytes) {
          throw const DocumentReadFailure(
            'En fazla 20 MB büyüklüğünde belge seç.',
          );
        }
        bytes = await file.readAsBytes();
      }
      return parsePolicyDocument(await readBytes(bytes));
    } on DocumentReadFailure {
      rethrow;
    } catch (_) {
      throw const DocumentReadFailure(
        'Belge okunamadı. Dosyanın şifresiz olduğundan ve fotoğrafın net olduğundan emin ol. Kamera iznini ve internet bağlantını da kontrol edebilirsin.',
      );
    }
  }

  Future<String> readBytes(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const DocumentReadFailure(
        'Boş olmayan, en fazla 20 MB bir belge seç.',
      );
    }
    final pdf =
        bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
    if (!pdf) {
      final jpeg =
          bytes.length > 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final png =
          bytes.length > 8 &&
          bytes[0] == 137 &&
          String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG';
      if (!jpeg && !png) {
        throw const DocumentReadFailure('PDF, JPG veya PNG belge seç.');
      }
      return recognizeDocumentImage(bytes);
    }
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      bytes,
      passwordProvider: () async => null,
    );
    try {
      if (document.pages.length > 10) {
        throw const DocumentReadFailure(
          'En fazla 10 sayfalık bir PDF seç. Poliçe bilgilerinin bulunduğu sayfaları kullanabilirsin.',
        );
      }
      final parts = <String>[];
      for (final page in document.pages) {
        final text = (await page.loadText())?.fullText ?? '';
        // Scanned pages have no usable text layer: read a rendered page by OCR.
        if (text.replaceAll(RegExp(r'\s'), '').length >= 30) {
          parts.add(text);
          continue;
        }
        final scale = math.min(2200 / page.width, 3000 / page.height);
        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) {
          throw const DocumentReadFailure('PDF sayfası okunamadı.');
        }
        try {
          final image = await rendered.createImage();
          try {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            if (png == null) {
              throw const DocumentReadFailure('PDF sayfası okunamadı.');
            }
            parts.add(await recognizeDocumentImage(png.buffer.asUint8List()));
          } finally {
            image.dispose();
          }
        } finally {
          rendered.dispose();
        }
      }
      return parts.join('\n');
    } finally {
      await document.dispose();
    }
  }
}

final policyDocumentImporterProvider = Provider<PolicyDocumentImporter>(
  (ref) => LocalPolicyDocumentImporter(),
);
