import '../../records/utils/record_calculations.dart';

/// Only explicitly labelled values are proposed. Never infer a price from
/// coverage limits, or a policy number from a person's identity number.
class PolicyDocumentFields {
  const PolicyDocumentFields({
    this.company,
    this.number,
    this.kind,
    this.level,
    this.step,
    this.startDate,
    this.endDate,
    this.premiumKurus,
  });
  final String? company, number, kind, level;
  final int? step, premiumKurus;
  final DateTime? startDate, endDate;
  bool get isEmpty =>
      company == null &&
      number == null &&
      kind == null &&
      level == null &&
      step == null &&
      startDate == null &&
      endDate == null &&
      premiumKurus == null;
}

String normalizePolicyText(String value) => value
    .replaceAll('İ', 'I')
    .replaceAll('ı', 'i')
    .toLowerCase()
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

PolicyDocumentFields parsePolicyDocument(String text) {
  final lines = text
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final normalized = normalizePolicyText(text);
  String? labelled(String labels) {
    final pattern = RegExp('^(?:$labels)\\s*[:=]?\\s*(.*)\$');
    final found = <String>{};
    for (var i = 0; i < lines.length; i++) {
      final match = pattern.firstMatch(normalizePolicyText(lines[i]));
      if (match == null) continue;
      final offset = match.group(0)!.length - match.group(1)!.length;
      final value = lines[i].substring(offset).trim();
      if (value.isNotEmpty) {
        found.add(value);
      } else if (i + 1 < lines.length && !lines[i + 1].contains(':')) {
        found.add(lines[i + 1]);
      }
    }
    // Multiple different policies in a document must not be silently combined.
    return found.length == 1 ? found.single : null;
  }

  DateTime? date(String? value) {
    if (value == null) return null;
    final m = RegExp(
      r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b',
    ).firstMatch(value);
    if (m == null) return null;
    final d = int.parse(m[1]!),
        month = int.parse(m[2]!),
        year = int.parse(m[3]!);
    final result = DateTime(year, month, d);
    return year >= 1900 &&
            year <= 2100 &&
            result.day == d &&
            result.month == month
        ? result
        : null;
  }

  String? company = labelled(
    r'(?:sigorta sirketi(?: unvani)?|sigortaci(?: sirket)?|sirket (?:adi|unvani))',
  );
  if (company != null &&
      (company.length > 100 ||
          !normalizePolicyText(company).contains('sigorta'))) {
    company = null;
  }
  String? number = labelled(r'police\s*(?:no(?:su)?|numarasi)\.?');
  if (number != null &&
      (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9/._-]{2,99}$').hasMatch(number) ||
          !RegExp(r'\d').hasMatch(number))) {
    number = null;
  }
  final kind = normalized.contains('kasko')
      ? 'casco'
      : (normalized.contains('zorunlu mali sorumluluk') ||
            normalized.contains('trafik sigorta'))
      ? 'traffic'
      : null;
  final level = normalized.contains('genisletilmis kasko')
      ? 'Genişletilmiş Kasko'
      : normalized.contains('dar kasko')
      ? 'Dar Kasko'
      : normalized.contains('tam kasko')
      ? 'Tam Kasko'
      : null;
  final stepText = labelled(
    r'(?:hasarsizlik basamagi|tarife basamagi|basamak(?: no)?)',
  );
  final stepMatch = stepText == null
      ? null
      : RegExp(
          r'^([0-8])(?:\.?\s*(?:basamak)?)?$',
        ).firstMatch(normalizePolicyText(stepText));
  final amountText = labelled(
    r'(?:odenecek (?:toplam )?prim|toplam brut prim|brut prim(?: tutari)?|toplam prim(?: tutari)?|police (?:tutari|primi))(?:\s*\((?:tl|try|₺)\))?',
  );
  int? amount;
  if (amountText != null) {
    final cleaned = amountText
        .replaceAll(RegExp(r'(?:TRY|TL|₺)', caseSensitive: false), '')
        .trim();
    String? numeric;
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+,\d{2}$').hasMatch(cleaned)) {
      numeric = cleaned.replaceAll('.', '');
    } else if (RegExp(r'^\d+(?:[,.]\d{1,2})?$').hasMatch(cleaned)) {
      numeric = cleaned;
    }
    amount = numeric == null
        ? null
        : RecordCalculations.scaledNumber(numeric, 2);
    if (amount != null && (amount <= 0 || amount > 100000000)) amount = null;
  }
  var start = date(
    labelled(
      r'(?:police )?(?:baslangic tarihi|sigorta baslangic tarihi|vade baslangici)',
    ),
  );
  var end = date(
    labelled(
      r'(?:police )?(?:bitis tarihi|sigorta bitis tarihi|vade bitisi|sona erme tarihi)',
    ),
  );
  if (start != null && end != null && !end.isAfter(start)) {
    start = null;
    end = null;
  }
  return PolicyDocumentFields(
    company: company,
    number: number,
    kind: kind,
    level: kind == 'casco' ? level : null,
    step: kind == 'traffic' && stepMatch != null
        ? int.parse(stepMatch[1]!)
        : null,
    startDate: start,
    endDate: end,
    premiumKurus: amount,
  );
}
