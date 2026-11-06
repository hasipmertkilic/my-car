import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/vehicle.dart';

class GarageVehicleCard extends StatelessWidget {
  const GarageVehicleCard({
    super.key,
    required this.vehicle,
    required this.index,
    required this.active,
    required this.onSelect,
    required this.onEdit,
    required this.onPolicies,
    required this.onRemove,
  });
  final Vehicle vehicle;
  final int index;
  final bool active;
  final VoidCallback? onSelect, onEdit, onPolicies, onRemove;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? c.primary.withValues(alpha: .4) : c.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            color: active ? c.primary : c.surfaceContainerHighest,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      index.toString().padLeft(2, '0'),
                      style: t.textTheme.headlineSmall?.copyWith(
                        color: c.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'GARAJ',
                        style: t.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Seçili',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(vehicle.name, style: t.textTheme.headlineMedium),
                const SizedBox(height: 5),
                Text(
                  '${vehicle.plate} • ${vehicle.year}',
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    _spec(
                      context,
                      'KİLOMETRE',
                      '${Formatters.number(vehicle.currentKm)} km',
                    ),
                    _spec(context, 'YAKIT', vehicle.fuelType),
                    _spec(context, 'VİTES', vehicle.transmission),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      onPressed: onSelect,
                      icon: Icon(
                        active ? Icons.check_rounded : Icons.north_east_rounded,
                        size: 17,
                      ),
                      label: Text(active ? 'Aktif araç' : 'Bu aracı seç'),
                    ),
                    OutlinedButton(
                      onPressed: onEdit,
                      child: const Text('Düzenle'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onPolicies,
                      icon: const Icon(Icons.shield_outlined, size: 17),
                      label: const Text('Poliçeler'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onRemove,
                      child: Text('Kaldır', style: TextStyle(color: c.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _spec(BuildContext context, String label, String value) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            letterSpacing: 1.2,
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(value, style: t.textTheme.titleSmall),
      ],
    );
  }
}
