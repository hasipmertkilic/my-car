import 'dart:math' as math;
import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.accent,
  });
  final IconData icon;
  final String label, value, detail;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final color = accent ?? c.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: t.textTheme.labelMedium?.copyWith(
                      color: c.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: t.textTheme.headlineSmall?.copyWith(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.3,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              detail,
              style: t.textTheme.bodySmall?.copyWith(
                color: c.onSurfaceVariant,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (children.isEmpty) return const SizedBox.shrink();
      final columns = math.min(
        children.length,
        box.maxWidth >= 760
            ? 4
            : box.maxWidth >= 340
            ? 2
            : 1,
      );
      return Column(
        children: [
          for (var start = 0; start < children.length; start += columns)
            Padding(
              padding: EdgeInsets.only(
                bottom: start + columns < children.length ? 12 : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 12),
                      Expanded(
                        child: start + column < children.length
                            ? children[start + column]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
