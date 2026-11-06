import 'package:flutter/services.dart';

class TurkishPlate {
  static final _groups = RegExp(r'^(\d{2})([A-Z]{1,3})(\d{2,5})$');
  static final _standard = RegExp(
    r'^(0[1-9]|[1-7][0-9]|8[01])(?:[A-PR-VYZ][0-9]{4,5}|[A-PR-VYZ]{2}[0-9]{3,4}|[A-PR-VYZ]{3}[0-9]{2,3})$',
  );

  static String _compact(String value) =>
      value.toUpperCase().replaceAll('İ', 'I').replaceAll(RegExp(r'\s+'), '');

  static String normalize(String value) {
    final upper = value.trim().toUpperCase().replaceAll('İ', 'I');
    final match = _groups.firstMatch(_compact(upper));
    return match == null ? upper : '${match[1]} ${match[2]} ${match[3]}';
  }

  static String? validate(String? value) {
    final compact = _compact(value ?? '');
    if (compact.isEmpty) return 'Plakanı gir.';
    if (!_standard.hasMatch(compact) ||
        int.tryParse(RegExp(r'[0-9]+$').firstMatch(compact)?.group(0) ?? '') ==
            0) {
      return 'Geçerli bir Türkiye plakası gir. Örn. 34 ABC 123.';
    }
    return null;
  }
}

class TurkishPlateInputFormatter extends TextInputFormatter {
  const TurkishPlateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final upper = newValue.text.toUpperCase().replaceAll('İ', 'I');
    if (!RegExp(r'^[0-9A-Z\s]*$').hasMatch(upper) || upper.length > 20) {
      return oldValue;
    }
    // Leave deletions editable, including deletion of an automatic separator.
    if (newValue.text.length < oldValue.text.length) {
      return newValue.copyWith(text: upper);
    }
    final compact = upper.replaceAll(RegExp(r'\s+'), '');
    final groups = RegExp(
      r'^(\d{0,2})([A-Z]{0,3})(\d{0,5})$',
    ).firstMatch(compact);
    if (groups == null || (groups[2]!.isNotEmpty && groups[1]!.length != 2)) {
      return oldValue;
    }
    final formatted = [
      groups[1]!,
      groups[2]!,
      groups[3]!,
    ].where((part) => part.isNotEmpty).join(' ');
    final rawOffset = newValue.selection.extentOffset;
    final beforeCursor = upper
        .substring(0, rawOffset.clamp(0, upper.length))
        .replaceAll(RegExp(r'\s+'), '')
        .length;
    var offset = 0, characters = 0;
    while (offset < formatted.length && characters < beforeCursor) {
      if (formatted[offset] != ' ') characters++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
