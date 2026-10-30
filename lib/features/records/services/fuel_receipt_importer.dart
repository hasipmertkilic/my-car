import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../insurance/services/document_ocr.dart';
import '../utils/record_calculations.dart';
import 'receipt_image_preprocessing.dart';

class FuelReceiptFields {
  const FuelReceiptFields({this.litersMilli, this.amountKurus});
  final int? litersMilli, amountKurus;
  bool get isEmpty => litersMilli == null && amountKurus == null;
}

String _normalizeReceipt(String text) => text
    .replaceAll('İ', 'I')
    .replaceAll('ı', 'i')
    .toLowerCase()
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    // Thermal printing can split BENZIN into BENZ IN / BENZ LN.
    .replaceAllMapped(
      RegExp(r'\b(k\s*)?benz\s*[il1]\s*n\b'),
      (m) => m[1] == null ? 'benzin' : 'kbenzin',
    )
    .replaceAllMapped(
      RegExp(r'(\d)([,.])[ \t]+(\d)'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );

FuelReceiptFields parseFuelReceipt(
  String text, {
  String additionalContext = '',
}) {
  final normalized = _normalizeReceipt(text);
  if (!RegExp(
    r'\b(motorin|dizel|diesel|eurodi|excellium|eurodizel|prodizel|vmaxdiesel|vpowerdiesel|kbenzin|benzin|kursunsuz(?:95|97)?|lpg|otogaz|akaryakit)\b',
  ).hasMatch('$normalized\n${_normalizeReceipt(additionalContext)}')) {
    return const FuelReceiptFields();
  }
  final liters = <int>{};
  int? scaled(String value, int decimals, int max) {
    var cleaned = value
        .trim()
        .replaceAll(RegExp(r'^[*₺\s]+'), '')
        .replaceAll(RegExp(r'\s*(?:tl|try|₺)$'), '')
        .trim();
    if (decimals == 2 &&
        RegExp(r'^\d{1,3}(?:\.\d{3})+,\d{2}$').hasMatch(cleaned)) {
      cleaned = cleaned.replaceAll('.', '');
    }
    final parsed = RecordCalculations.scaledNumber(cleaned, decimals);
    return parsed != null && parsed > 0 && parsed <= max ? parsed : null;
  }

  void addLiters(String value) {
    final parsed = scaled(value, 3, 1000000);
    if (parsed != null) liters.add(parsed);
  }

  final lines = normalized
      .split(RegExp(r'[\r\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  for (var index = 0; index < lines.length; index++) {
    var line = lines[index];
    if (RegExp(
          r'^(?:genel toplam|toplam(?: tutar)?|odenecek(?: tutar)?|satis tutari|tutar|litre|miktar)\s*[:=]?$',
        ).hasMatch(line) &&
        index + 1 < lines.length) {
      line = '${line.replaceFirst(RegExp(r'[:=]$'), '')}: ${lines[index + 1]}';
    }
    // A currency-per-litre price is not the purchased volume.
    if (!RegExp(
      r'(?:tl|try|₺)\s*/\s*(?:lt|l)|birim|litre fiyati',
    ).hasMatch(line)) {
      for (final m in RegExp(
        r'(?<![\d.,])\b(\d+(?:[,.]\d{1,3})?)\s*(?:litre|lt|l)(?:\b|(?=[x×*]))',
      ).allMatches(line)) {
        addLiters(m[1]!);
      }
      final labelled = RegExp(
        r'^\s*(?:alinan yakit(?: miktari)?|litre|miktar(?:\s*\((?:lt|litre)\))?)\s*[:=]\s*(\d+(?:[,.]\d{1,3})?)\s*(?:lt|litre|l)?\s*$',
      ).firstMatch(line);
      if (labelled != null) addLiters(labelled[1]!);
    }
  }
  return FuelReceiptFields(
    litersMilli: liters.length == 1 ? liters.single : null,
    amountKurus: receiptPaymentAmount(lines),
  );
}

FuelReceiptFields mergeFuelReceiptReadings(String prepared, String original) {
  final first = parseFuelReceipt(prepared, additionalContext: original);
  final second = parseFuelReceipt(original, additionalContext: prepared);
  int? consistent(int? a, int? b) => a == null
      ? b
      : b == null || a == b
      ? a
      : null;
  return FuelReceiptFields(
    litersMilli: consistent(first.litersMilli, second.litersMilli),
    amountKurus: consistent(first.amountKurus, second.amountKurus),
  );
}

/// Currency values may be split across OCR lines or printed with dotted
/// leaders. Only read values attached to total/payment labels, never KDV or
/// the number in a unit-price/product row.
int? receiptPaymentAmount(List<String> sourceLines) {
  final lines = sourceLines
      .map(
        (line) => line
            .replaceAll('\u00a0', ' ')
            .replaceAll(RegExp(r't[0o]p\s*lam'), 'toplam'),
      )
      .toList();
  int? money(String raw) {
    var value = raw
        .trim()
        .replaceFirst(RegExp(r'^(?:[\s*#+₺:=·…|¦-]|\.(?=\s)|\.{2,})+'), '')
        .replaceFirst(RegExp(r'\s*[|¦]+\s*$'), '')
        .replaceFirst(RegExp(r'^(?:tl|try)\s*[:*]?\s*'), '')
        .replaceFirst(RegExp(r'\s*(?:tl|try|₺)\s*$'), '')
        .trim();
    // Whitespace around the decimal separator is a common OCR artifact.
    value = value.replaceAllMapped(
      RegExp(r'([,.])\s+(\d{2})$'),
      (m) => '${m[1]}${m[2]}',
    );
    if (RegExp(r'^\d{1,3}(?: \d{3})+(?:[,.]\d{2})$').hasMatch(value)) {
      value = value.replaceAll(' ', '');
    }
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+[,\.]\d{2}$').hasMatch(value)) {
      final decimalIndex = value.length - 3;
      value =
          '${value.substring(0, decimalIndex).replaceAll('.', '')}.${value.substring(decimalIndex + 1)}';
    } else if (RegExp(r'^\d{1,3}(?:,\d{3})+\.\d{2}$').hasMatch(value)) {
      value = value.replaceAll(',', '');
    }
    final amount = RecordCalculations.scaledNumber(value, 2);
    return amount != null && amount > 0 && amount <= 100000000 ? amount : null;
  }

  const totalLabels =
      r'(?:genel\s*toplam|topla[mn]\s*(?:tutari?|odeme)?|t[0o]p\.?\s*(?:tutari?)?(?=[\s:=*₺.(0-9]|$)|odenecek\s*(?:tutar|toplam)?|satis\s*tutari?|tutari?)';
  const cardLabels =
      r'(?:kredi\s*karti|banka\s*karti|kredi|kart(?:li odeme)?|nakit)';
  Set<int> collect(String labels, {bool cashAllowed = false}) {
    final result = <int>{};
    final pattern = RegExp(
      '^[*\\s]*(?:$labels)(?:\\s*\\(?\\s*(?:tl|try|₺)\\s*\\)?)?\\s*(.*)\$',
    );
    for (var i = 0; i < lines.length; i++) {
      if (!cashAllowed && lines[i].startsWith('nakit')) continue;
      final match = pattern.firstMatch(lines[i]);
      if (match == null) continue;
      final tail = match[1]!;
      final inline = money(tail);
      if (inline != null) {
        result.add(inline);
        continue;
      }
      // Only cross empty/currency/leader lines; do not jump over another label.
      if (!RegExp(r'^[\s:=.*·…()₺|¦0-]*$').hasMatch(tail)) continue;
      for (var next = i + 1; next < lines.length && next <= i + 3; next++) {
        final amount = money(lines[next]);
        if (amount != null) {
          result.add(amount);
          break;
        }
        if (!RegExp(
          r'^[\s:=.*·…()₺|¦0-]*(?:tl|try)?[\s:=.*·…()₺|¦0-]*$',
        ).hasMatch(lines[next])) {
          break;
        }
      }
    }
    return result;
  }

  final totals = collect(totalLabels);
  if (totals.isNotEmpty) return totals.length == 1 ? totals.single : null;
  // A single card/cash payment can recover an unreadable total. Do not treat
  // cash tendered as payment when change is present, or add split payments.
  final hasChange = lines.any(
    (line) => RegExp(r'para\s*ustu|iade|change').hasMatch(line),
  );
  final payments = collect(cardLabels, cashAllowed: !hasChange);
  final paymentRows = lines
      .where(
        (line) => RegExp('^[*\\s]*$cardLabels(?:\\s|[:=*]|\$)').hasMatch(line),
      )
      .length;
  return paymentRows == 1 && payments.length == 1 ? payments.single : null;
}

enum FuelReceiptSource { camera, gallery }

class FuelReceiptFailure implements Exception {
  const FuelReceiptFailure(this.message);
  final String message;
}

abstract interface class FuelReceiptImporter {
  Future<FuelReceiptFields?> read(FuelReceiptSource source);
}

class LocalFuelReceiptImporter implements FuelReceiptImporter {
  @override
  Future<FuelReceiptFields?> read(FuelReceiptSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source == FuelReceiptSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 3200,
        imageQuality: 95,
      );
      if (image == null) return null;
      if (await image.length() > 20 * 1024 * 1024) {
        throw const FuelReceiptFailure('En fazla 20 MB bir fiş fotoğrafı seç.');
      }
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        throw const FuelReceiptFailure('Fotoğraf boş veya okunamıyor.');
      }
      final prepared = await compute(prepareReceiptImage, bytes);
      final preparedText = await recognizeDocumentImage(
        prepared,
        receiptLayout: true,
        sparseText: true,
      );
      final fields = parseFuelReceipt(preparedText);
      if (fields.litersMilli != null && fields.amountKurus != null) {
        return fields;
      }
      final originalText = await recognizeDocumentImage(
        bytes,
        receiptLayout: true,
      );
      return mergeFuelReceiptReadings(preparedText, originalText);
    } on FuelReceiptFailure {
      rethrow;
    } catch (_) {
      throw const FuelReceiptFailure(
        'Fiş okunamadı. Net bir fotoğrafla tekrar dene veya bilgileri elle gir. Kamera ve fotoğraf izinlerini de kontrol edebilirsin.',
      );
    }
  }
}

final fuelReceiptImporterProvider = Provider<FuelReceiptImporter>(
  (ref) => LocalFuelReceiptImporter(),
);
