import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../repositories/parking_repository.dart';
import '../services/parking_location.dart';
import 'parking_map.dart';
import 'navigate_to_car_button.dart';

class ParkingCard extends ConsumerStatefulWidget {
  const ParkingCard({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  ConsumerState<ParkingCard> createState() => _ParkingCardState();
}

class _ParkingCardState extends ConsumerState<ParkingCard> {
  bool busy = false;
  Future<void> finish() async {
    if (busy) return;
    final repository = ref.read(parkingRepositoryProvider);
    if (repository == null) return;
    setState(() => busy = true);
    try {
      await repository.finish(widget.vehicleId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Park kaydı kapatılamadı. Tekrar dene.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(parkingProvider(widget.vehicleId))
      .when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Card(
          child: ListTile(
            title: const Text('Park bilgisi yüklenemedi'),
            trailing: IconButton(
              tooltip: 'Park bilgisini tekrar yükle',
              onPressed: () =>
                  ref.invalidate(parkingProvider(widget.vehicleId)),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        data: (place) => Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Park yerim',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (place == null)
                  const Text('Henüz park yeri kaydetmedin.')
                else ...[
                  Text(place.indoor ? 'Kapalı otopark' : 'Açık alan'),
                  Text(
                    place.description,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (place.notes.isNotEmpty) Text(place.notes),
                  Text(
                    'Kaydedildi: ${Formatters.date(place.savedAt)} • ${place.savedAt.hour.toString().padLeft(2, '0')}:${place.savedAt.minute.toString().padLeft(2, '0')}',
                  ),
                  if (place.hasCoordinates) ...[
                    const SizedBox(height: 12),
                    ParkingMap(
                      latitude: place.latitude,
                      longitude: place.longitude,
                      label: place.indoor
                          ? 'Otopark giriş konumu'
                          : 'Aracının park yeri',
                    ),
                    const SizedBox(height: 12),
                    NavigateToCarButton(place: place),
                    const Text(
                      'Google Haritalar’da bulunduğun konumdan yürüyüş rotası açılır.',
                    ),
                  ],
                  if (place.indoor && !place.hasCoordinates)
                    const Text(
                      'Giriş konumu kaydedilmemiş. Haritada rota için park kaydına giriş konumu ekleyebilirsin.',
                    ),
                  if (place.hasCoordinates)
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                if (await ref
                                    .read(parkingLocationProvider)
                                    .openMap(place)) {
                                  return;
                                }
                              } catch (_) {
                                /* Aşağıda kullanıcıya hata gösterilir. */
                              }
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => context.push(
                              '/vehicles/${widget.vehicleId}/parking',
                            ),
                      child: Text(
                        place == null
                            ? 'Park yeri kaydet'
                            : 'Park yerini güncelle',
                      ),
                    ),
                    if (place != null)
                      TextButton(
                        onPressed: busy ? null : finish,
                        child: Text(busy ? 'Kaydediliyor…' : 'Aracı aldım'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
