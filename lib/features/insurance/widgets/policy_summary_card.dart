import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/status_colors.dart';
import '../../inspection/repositories/inspection_repository.dart';
import '../models/insurance_policy.dart';
import '../repositories/policy_repository.dart';

class PolicySummaryCard extends ConsumerWidget {
  const PolicySummaryCard({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(policiesProvider(vehicleId))
      .when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Card(
          child: ListTile(
            title: const Text('Poliçeler yüklenemedi'),
            trailing: IconButton(
              tooltip: 'Poliçeleri tekrar yükle',
              onPressed: () => ref.invalidate(policiesProvider(vehicleId)),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        data: (policies) {
          final now = ref.watch(inspectionClockProvider);
          final selected = ['traffic', 'casco']
              .map((kind) => relevantPolicy(policies, kind, now))
              .nonNulls
              .toList();
          final expired = selected.any(
            (p) => p.started(now) && p.daysUntil(now) < 0,
          );
          final urgent = selected.any(
            (p) => p.started(now) && p.daysUntil(now) <= 30,
          );
          return Card(
            color: urgent
                ? StatusColors.background(
                    context,
                    expired ? RecordStatus.overdue : RecordStatus.attention,
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sigorta ve kasko',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (selected.isEmpty) const Text('Henüz poliçe kaydetmedin.'),
                  for (final p in selected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.title} • ${p.levelLabel}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${p.company} • ${p.status(now)}',
                            style: TextStyle(
                              color: StatusColors.foreground(
                                context,
                                p.started(now)
                                    ? StatusColors.forDays(p.daysUntil(now))
                                    : RecordStatus.attention,
                              ),
                            ),
                          ),
                          Text('Bitiş: ${Formatters.date(p.endDate)}'),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/vehicles/$vehicleId/policies'),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Poliçelerim'),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
