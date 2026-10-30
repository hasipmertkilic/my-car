import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import 'maintenance_entry.dart';

class MaintenanceHistoryCard extends StatelessWidget {
  const MaintenanceHistoryCard({
    super.key,
    required this.entry,
    required this.latest,
    required this.onEdit,
  });
  final MaintenanceEntry entry;
  final bool latest;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = latest ? colors.primary : colors.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: latest ? .13 : .04),
            colors.surfaceContainerLow,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: latest ? .35 : .13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.car_repair_rounded, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest ? 'SON BAKIM' : 'BAKIM KAYDI',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.date(entry.date),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tiles = [
                  _Fact(
                    icon: Icons.speed_rounded,
                    label: 'Bakım kilometresi',
                    value: '${Formatters.number(entry.odometerKm)} km',
                  ),
                  _Fact(
                    icon: Icons.payments_outlined,
                    label: 'Bakım tutarı',
                    value: entry.amountKurus == 0
                        ? 'Belirtilmedi'
                        : Formatters.preciseMoney(entry.amountKurus / 100),
                  ),
                ];
                if (constraints.maxWidth < 290 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [tiles[0], const SizedBox(height: 8), tiles[1]],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: 8),
                    Expanded(child: tiles[1]),
                  ],
                );
              },
            ),
          ),
          ExpansionTile(
            key: ValueKey('${entry.id}-$latest'),
            initiallyExpanded: latest,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 18),
            title: Text(
              'Değişen parçalar ve işlemler',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${entry.items.length} parça • ${Formatters.number(entry.intervalKm)} km bakım aralığı',
              style: theme.textTheme.bodySmall,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entry.items.isNotEmpty)
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final item in entry.items)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          maintenanceItems[item] ?? item,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
              if (entry.details.isNotEmpty)
                _Detail(
                  icon: Icons.fact_check_outlined,
                  label: 'Diğer işlemler',
                  text: entry.details,
                ),
              if (entry.service.isNotEmpty)
                _Detail(
                  icon: Icons.storefront_outlined,
                  label: 'Servis / usta',
                  text: entry.service,
                ),
              if (entry.notes.isNotEmpty)
                _Detail(
                  icon: Icons.notes_rounded,
                  label: 'Notlar',
                  text: entry.notes,
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Kaydı düzenle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.primary),
          const SizedBox(height: 7),
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.text});
  final IconData icon;
  final String label, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 3),
              Text('$label: $text'),
            ],
          ),
        ),
      ],
    ),
  );
}
