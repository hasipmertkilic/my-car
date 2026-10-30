import 'package:flutter/material.dart';

enum RecordStatus { overdue, attention, valid }

abstract final class StatusColors {
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static RecordStatus forDays(int days) => days < 0
      ? RecordStatus.overdue
      : days <= 30
      ? RecordStatus.attention
      : RecordStatus.valid;
  static Color foreground(BuildContext context, RecordStatus status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      RecordStatus.overdue => dark ? error : const Color(0xFFB91C1C),
      RecordStatus.attention => dark ? warning : const Color(0xFF92400E),
      RecordStatus.valid => dark ? success : const Color(0xFF047857),
    };
  }

  static Color background(BuildContext context, RecordStatus status) =>
      Color.alphaBlend(
        foreground(context, status).withValues(alpha: .12),
        Theme.of(context).colorScheme.surface,
      );
}
