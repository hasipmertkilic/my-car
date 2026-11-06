import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/activity_record.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/activity_controller.dart';

class ActivityCard extends ConsumerWidget {
  const ActivityCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onRemove,
  });
  final ActivityRecord record;
  final VoidCallback? onEdit, onRemove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final accent = record.isFuel ? c.secondary : c.primary;
    final pending = ref
        .watch(offlineRecordStateProvider)
        .asData
        ?.value
        ?.pending
        .where((p) => p.record.id == record.id)
        .lastOrNull;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                record.isFuel
                    ? Icons.local_gas_station_outlined
                    : Icons.payments_outlined,
                color: accent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.isFuel ? 'YAKIT KAYDI' : 'MASRAF KAYDI',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: accent,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                Formatters.date(record.date),
                style: t.textTheme.bodySmall?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            Formatters.preciseMoney(record.amount),
            style: t.textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(record.title, style: t.textTheme.titleMedium),
          if (pending != null)
            Text(
              pending.error ?? 'Cihazda kayıtlı • Eşitleme bekliyor',
              style: t.textTheme.bodySmall?.copyWith(
                color: pending.error == null ? c.onSurfaceVariant : c.error,
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '${Formatters.number(record.odometerKm)} km',
                style: t.textTheme.bodySmall?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
              if (record.isFuel)
                Text(
                  '${Formatters.number(record.liters)} litre • ${record.fullTank ? 'Dolu depo' : 'Kısmi dolum'}',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (record.isFuel) ...[
            const SizedBox(height: 6),
            Text(
              'Litre fiyatı: ${Formatters.preciseMoney(record.pricePerLiter!)}',
              style: t.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
          if (record.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(record.notes),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Düzenle'),
              ),
              TextButton(
                onPressed: onRemove,
                child: Text('Kaldır', style: TextStyle(color: c.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
