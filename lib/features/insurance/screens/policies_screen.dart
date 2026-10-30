import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/status_colors.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../../inspection/repositories/inspection_repository.dart';
import '../models/insurance_policy.dart';
import '../repositories/policy_repository.dart';

class PoliciesScreen extends ConsumerStatefulWidget {
  const PoliciesScreen({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  ConsumerState<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends ConsumerState<PoliciesScreen> {
  bool busy = false;
  Future<void> archive(InsurancePolicy policy, {bool restore = false}) async {
    if (busy) {
      return;
    }
    final repository = ref.read(policyRepositoryProvider);
    if (repository == null) {
      return;
    }
    setState(() => busy = true);
    try {
      await repository.archive(widget.vehicleId, policy.id, archived: !restore);
      if (mounted && !restore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Poliçe arşivlendi.'),
            action: SnackBarAction(
              label: 'Geri al',
              onPressed: () => archive(policy, restore: true),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poliçe güncellenemedi. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Poliçelerim'),
      leading: IconButton(
        tooltip: 'Özete dön',
        onPressed: () => context.go('/summary'),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: VehicleScope(
      allowEmpty: true,
      builder: (_) {
        final vehicle = ref
            .watch(vehiclesProvider)
            .asData!
            .value
            .where((v) => v.id == widget.vehicleId)
            .firstOrNull;
        if (vehicle == null) {
          return const Center(child: Text('Araç bulunamadı.'));
        }
        final now = ref.watch(inspectionClockProvider);
        return PageContent(
          children: [
            SectionTitle(
              vehicle.name,
              subtitle: '${vehicle.plate} • Sigorta ve kasko poliçelerin',
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => context.push(
                      '/vehicles/${widget.vehicleId}/policies/new',
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Poliçe ekle'),
            ),
            const SizedBox(height: 20),
            ref
                .watch(policiesProvider(widget.vehicleId))
                .when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => FilledButton(
                    onPressed: () =>
                        ref.invalidate(policiesProvider(widget.vehicleId)),
                    child: const Text('Yüklenemedi. Tekrar dene'),
                  ),
                  data: (policies) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (policies.isEmpty)
                        const Text(
                          'Henüz poliçe eklemedin. Trafik sigortası veya kasko bilgilerini kaydederek başla.',
                        ),
                      for (final p in policies)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  p.company,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text('Poliçe no: ${p.number}'),
                                Text(p.levelLabel),
                                const SizedBox(height: 8),
                                Text(
                                  '${Formatters.date(p.startDate)} – ${Formatters.date(p.endDate)}',
                                ),
                                Text(
                                  p.status(now),
                                  style: TextStyle(
                                    color: StatusColors.foreground(
                                      context,
                                      p.started(now)
                                          ? StatusColors.forDays(
                                              p.daysUntil(now),
                                            )
                                          : RecordStatus.attention,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Poliçe tutarı: ${Formatters.preciseMoney(p.premiumKurus / 100)}',
                                ),
                                if (p.notes.isNotEmpty) Text(p.notes),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => context.push(
                                              '/vehicles/${widget.vehicleId}/policies/${p.id}/edit',
                                            ),
                                      child: const Text('Düzenle'),
                                    ),
                                    TextButton(
                                      onPressed: busy ? null : () => archive(p),
                                      child: const Text('Arşivle'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        );
      },
    ),
  );
}
