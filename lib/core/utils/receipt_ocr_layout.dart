class ReceiptOcrLine {
  const ReceiptOcrLine(this.text, this.left, this.top, this.width, this.height);
  final String text;
  final double left, top, width, height;
  double get centerY => top + height / 2;
}

/// ML Kit groups the left labels and right prices into separate text blocks.
/// Reconstruct physical rows before interpreting labels and amounts.
String receiptTextInReadingOrder(List<ReceiptOcrLine> input) {
  final sorted =
      input.where((l) => l.text.trim().isNotEmpty && l.height > 0).toList()
        ..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<ReceiptOcrLine>>[];
  for (final line in sorted) {
    List<ReceiptOcrLine>? target;
    for (final row in rows.reversed) {
      final anchor = row.first;
      final minHeight = anchor.height < line.height
          ? anchor.height
          : line.height;
      final overlapTop = anchor.top > line.top ? anchor.top : line.top;
      final anchorBottom = anchor.top + anchor.height;
      final lineBottom = line.top + line.height;
      final overlapBottom = anchorBottom < lineBottom
          ? anchorBottom
          : lineBottom;
      if (overlapBottom - overlapTop < minHeight * .65) continue;
      final separate = row.every(
        (other) =>
            line.left >= other.left + other.width ||
            other.left >= line.left + line.width,
      );
      if (separate) {
        target = row;
        break;
      }
    }
    if (target == null) {
      rows.add([line]);
    } else {
      target.add(line);
    }
  }
  return rows
      .map((row) {
        row.sort((a, b) => a.left.compareTo(b.left));
        return row.map((line) => line.text.trim()).join(' ');
      })
      .join('\n');
}
