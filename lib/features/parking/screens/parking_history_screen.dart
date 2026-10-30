import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/utils/formatters.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../repositories/parking_repository.dart';
import '../services/parking_location.dart';
import '../widgets/navigate_to_car_button.dart';

class ParkingHistoryScreen extends ConsumerWidget {
  const ParkingHistoryScreen({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Park yerlerim'),
      leading: IconButton(
        tooltip: 'Park bölümüne dön',
        onPressed: () => context.go('/parking'),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: VehicleScope(
      allowEmpty: true,
      builder: (_) {
        final car = ref
            .watch(vehiclesProvider)
            .asData!
            .value
            .where((v) => v.id == vehicleId)
            .firstOrNull;
        if (car == null) return const Center(child: Text('Araç bulunamadı.'));
        return ref
            .watch(parkingHistoryProvider(vehicleId))
            .when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: FilledButton(
                  onPressed: () =>
                      ref.invalidate(parkingHistoryProvider(vehicleId)),
                  child: const Text('Yüklenemedi. Tekrar dene'),
                ),
              ),
              data: (places) => PageContent(
                children: [
                  SectionTitle(
                    car.name,
                    subtitle:
                        'Son 5 tamamlanan park kaydın. Yeni kayıt geldiğinde en eskisi kaldırılır.',
                  ),
                  if (places.isEmpty)
                    const Text(
                      'Henüz park geçmişin yok. “Aracı aldım” dediğinde park yerin burada saklanır.',
                    ),
                  for (final place in places)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.indoor ? 'Kapalı otopark' : 'Açık alan',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(place.description),
                            if (place.notes.isNotEmpty) Text(place.notes),
                            Text(
                              'Park tarihi: ${Formatters.date(place.savedAt)} • ${place.savedAt.hour.toString().padLeft(2, '0')}:${place.savedAt.minute.toString().padLeft(2, '0')}',
                            ),
                            if (place.hasCoordinates) ...[
                              const SizedBox(height: 8),
                              NavigateToCarButton(
                                place: place,
                                label: 'Buraya git',
                              ),
                            ],
                            if (place.hasCoordinates)
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    if (await ref
                                        .read(parkingLocationProvider)
                                        .openMap(place)) {
                                      return;
                                    }
                                  } catch (_) {}
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Harita açılamadı. Tekrar dene.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Google Haritalar’da göster'),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
      },
    ),
  );
}
