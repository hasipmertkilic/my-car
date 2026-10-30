import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/status_colors.dart';
import '../repositories/inspection_repository.dart';

class InspectionCard extends ConsumerWidget {
  const InspectionCard({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(inspectionProvider(vehicleId))
      .when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Card(
          child: ListTile(
            title: const Text('Muayene bilgisi yüklenemedi'),
            trailing: IconButton(
              tooltip: 'Muayeneyi tekrar yükle',
              onPressed: () => ref.invalidate(inspectionProvider(vehicleId)),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        data: (schedule) {
          final now = ref.watch(inspectionClockProvider);
          final days = schedule?.daysUntil(now);
          final scheme = Theme.of(context).colorScheme;
          final urgent = days != null && days <= 30;
          final status = days == null ? null : StatusColors.forDays(days);
          return Card(
            color: status == null
                ? scheme.surfaceContainer
                : StatusColors.background(context, status),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        urgent
                            ? Icons.warning_amber_rounded
                            : Icons.fact_check_outlined,
                        color: status == null
                            ? null
                            : StatusColors.foreground(context, status),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Muayene',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (schedule == null)
                    const Text('Henüz muayene bilgisi kaydetmedin.')
                  else ...[
                    Text(
                      schedule.status(now),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: status == null
                            ? null
                            : StatusColors.foreground(context, status),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Son muayene: ${Formatters.date(schedule.lastDate)}'),
                    Text(
                      'Sonraki muayene: ${Formatters.date(schedule.nextDate)} • ${schedule.intervalYears} yıl aralıkla',
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        context.push('/vehicles/$vehicleId/inspection'),
                    child: Text(
                      schedule == null
                          ? 'Muayene bilgisi ekle'
                          : 'Muayeneyi güncelle',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
