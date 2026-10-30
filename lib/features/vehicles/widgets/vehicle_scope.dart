import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../controllers/vehicle_controller.dart';
import '../models/vehicle.dart';

class VehicleScope extends ConsumerWidget {
  const VehicleScope({
    super.key,
    required this.builder,
    this.allowEmpty = false,
  });
  final Widget Function(Vehicle? vehicle) builder;
  final bool allowEmpty;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    final activeId = ref.watch(activeVehicleIdProvider);
    if (vehicles.hasError || activeId.hasError) {
      return PageContent(
        children: [
          const SectionTitle(
            'Araçların yüklenemedi',
            subtitle: 'Bağlantını ve Firestore erişim izinlerini kontrol et.',
          ),
          FilledButton(
            onPressed: () {
              ref.invalidate(vehiclesProvider);
              ref.invalidate(activeVehicleIdProvider);
            },
            child: const Text('Tekrar dene'),
          ),
        ],
      );
    }
    if (vehicles.isLoading || activeId.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final vehicle = ref.watch(activeVehicleProvider);
    if (vehicle == null && !allowEmpty) {
      return PageContent(
        children: [
          const SectionTitle(
            'Garajın seni bekliyor',
            subtitle: 'İlk aracını ekleyerek başlayalım.',
          ),
          const Icon(Icons.directions_car_outlined, size: 80),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/vehicles/new'),
            icon: const Icon(Icons.add),
            label: const Text('İlk aracımı ekle'),
          ),
        ],
      );
    }
    return builder(vehicle);
  }
}
