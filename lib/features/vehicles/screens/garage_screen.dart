import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/garage_vehicle_card.dart';
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
          PageHeading(
            'Garajım',
            eyebrow: 'ARAÇ KOLEKSİYONUN',
            subtitle:
                '${vehicles.length} kayıtlı araç • Birini seçerek takibine devam et.',
          ),
          if (vehicles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(Icons.garage_outlined, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Henüz araç eklemedin. İlk aracını aşağıdan ekleyebilirsin.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < vehicles.length; i++) ...[
            GarageVehicleCard(
              vehicle: vehicles[i],
              index: i + 1,
              active: vehicles[i].id == active?.id,
              onSelect: busy
                  ? null
                  : () =>
                        run((repository) => repository.select(vehicles[i].id)),
              onEdit: busy
                  ? null
                  : () => context.push('/vehicles/${vehicles[i].id}/edit'),
              onPolicies: busy
                  ? null
                  : () => context.push('/vehicles/${vehicles[i].id}/policies'),
              onRemove: busy ? null : () => remove(vehicles[i]),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
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
