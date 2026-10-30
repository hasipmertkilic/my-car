import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_content.dart';
import '../controllers/vehicle_controller.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import '../widgets/vehicle_scope.dart';

class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});
  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  bool busy = false;
  Future<void> run(Future<void> Function(VehicleRepository) action) async {
    if (busy) return;
    final repository = ref.read(vehicleRepositoryProvider);
    if (repository == null) return;
    setState(() => busy = true);
    try {
      await action(repository);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is VehicleFailure
                  ? error.message
                  : 'İşlem tamamlanamadı. Tekrar dene.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aracı garajdan kaldır?'),
        content: Text(
          '${vehicle.name} garajında görünmeyecek. Verileri arşivlenir; işlemden sonra Geri al ile yeniden ekleyebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await run((repository) async {
      await repository.archive(vehicle.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vehicle.name} kaldırıldı.'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Geri al',
              onPressed: () =>
                  run((repository) => repository.restore(vehicle.id)),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => VehicleScope(
    allowEmpty: true,
    builder: (active) {
      final vehicles = ref.watch(vehiclesProvider).asData!.value;
      return PageContent(
        children: [
          const SectionTitle(
            'Garajım',
            subtitle:
                'Araçların hesabına kaydedilir ve cihazların arasında güncellenir.',
          ),
          if (vehicles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Henüz araç eklemedin. İlk aracını aşağıdan ekleyebilirsin.',
              ),
            ),
          for (final vehicle in vehicles) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.directions_car_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            vehicle.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${vehicle.plate} • ${vehicle.year}'),
                    const SizedBox(height: 8),
                    Text(
                      '${Formatters.number(vehicle.currentKm)} km • ${vehicle.fuelType} • ${vehicle.transmission}',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: busy || vehicle.id == active?.id
                              ? null
                              : () => run(
                                  (repository) => repository.select(vehicle.id),
                                ),
                          icon: Icon(
                            vehicle.id == active?.id
                                ? Icons.check_circle_outline
                                : Icons.swap_horiz,
                          ),
                          label: Text(
                            vehicle.id == active?.id
                                ? 'Aktif araç'
                                : 'Bu aracı seç',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => context.push(
                                  '/vehicles/${vehicle.id}/edit',
                                ),
                          child: const Text('Düzenle'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => context.push(
                                  '/vehicles/${vehicle.id}/policies',
                                ),
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Poliçeler'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => remove(vehicle),
                          child: const Text('Kaldır'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          FilledButton.icon(
            onPressed: busy ? null : () => context.push('/vehicles/new'),
            icon: const Icon(Icons.add),
            label: const Text('Yeni araç ekle'),
          ),
        ],
      );
    },
  );
}
