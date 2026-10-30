import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../models/parking_place.dart';
import '../repositories/parking_repository.dart';
import '../services/parking_location.dart';
import '../widgets/parking_map.dart';

class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => VehicleScope(
    allowEmpty: true,
    builder: (_) {
      final car = ref
          .watch(vehiclesProvider)
          .asData!
          .value
          .where((v) => v.id == vehicleId)
          .firstOrNull;
      if (car == null) {
        return const Scaffold(body: Center(child: Text('Araç bulunamadı.')));
      }
      return ref
          .watch(parkingProvider(vehicleId))
          .when(
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: false,
            data: (place) => ParkingForm(
              key: ValueKey(vehicleId),
              vehicleId: vehicleId,
              name: car.name,
              initial: place,
            ),
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Scaffold(
              appBar: AppBar(title: const Text('Park yerim')),
              body: Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(parkingProvider(vehicleId)),
                  child: const Text('Yüklenemedi. Tekrar dene'),
                ),
              ),
            ),
          );
    },
  );
}

class ParkingForm extends ConsumerStatefulWidget {
  const ParkingForm({
    super.key,
    required this.vehicleId,
    required this.name,
    this.initial,
  });
  final String vehicleId, name;
  final ParkingPlace? initial;
  @override
  ConsumerState<ParkingForm> createState() => _ParkingFormState();
}

class _ParkingFormState extends ConsumerState<ParkingForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController floor, section, space, notes;
  late bool indoor;
  ParkCoordinates? coordinates;
  DateTime? locatedAt;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    indoor = initial?.indoor ?? false;
    floor = TextEditingController(text: initial?.floor);
    section = TextEditingController(text: initial?.section);
    space = TextEditingController(text: initial?.space);
    notes = TextEditingController(text: initial?.notes);
    if (initial != null && initial.hasCoordinates) {
      coordinates = ParkCoordinates(
        initial.latitude!,
        initial.longitude!,
        initial.accuracy!,
      );
      locatedAt = initial.savedAt;
    }
  }

  @override
  void dispose() {
    floor.dispose();
    section.dispose();
    space.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final point = await ref.read(parkingLocationProvider).locate();
      if (mounted) {
        setState(() {
          coordinates = point;
          locatedAt = DateTime.now();
        });
      }
    } on ParkingFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Konum alınamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (!indoor && coordinates == null) {
      setState(() => error = 'Önce park konumunu al.');
      return;
    }
    final repository = ref.read(parkingRepositoryProvider);
    if (repository == null) {
      setState(() => error = 'Hesap bağlantısı hazır değil. Tekrar dene.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.save(
        widget.vehicleId,
        ParkingPlace(
          indoor: indoor,
          savedAt: DateTime.now(),
          latitude: coordinates?.latitude,
          longitude: coordinates?.longitude,
          accuracy: coordinates?.accuracy,
          floor: indoor ? floor.text.trim() : '',
          section: indoor ? section.text.trim().toUpperCase() : '',
          space: indoor ? space.text.trim() : '',
          notes: notes.text.trim(),
        ),
      );
      if (mounted) context.go('/summary');
    } on ParkingFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Park yeri kaydedilemedi. Tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Park yerim'),
        leading: IconButton(
          tooltip: 'Özete dön',
          onPressed: busy ? null : () => context.go('/summary'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: PageContent(
        children: [
          SectionTitle(
            widget.name,
            subtitle: 'Aracını nereye park ettiğini kaydet.',
          ),
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Açık alan'),
                      icon: Icon(Icons.map_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Kapalı otopark'),
                      icon: Icon(Icons.local_parking),
                    ),
                  ],
                  selected: {indoor},
                  onSelectionChanged: busy
                      ? null
                      : (selection) => setState(() {
                          indoor = selection.first;
                          error = null;
                        }),
                ),
                const SizedBox(height: 20),
                if (!indoor) ...[
                  ParkingMap(
                    latitude: coordinates?.latitude,
                    longitude: coordinates?.longitude,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Park ettiğin noktadayken konumunu al. Konum, kaydettiğinde hesabına eklenir.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : locate,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      coordinates == null ? 'Konumumu al' : 'Konumu yeniden al',
                    ),
                  ),
                  if (coordinates != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${coordinates!.latitude.toStringAsFixed(6)}, ${coordinates!.longitude.toStringAsFixed(6)}',
                    ),
                    Text(
                      'Konum doğruluğu: yaklaşık ${coordinates!.accuracy.round()} metre',
                    ),
                    if (locatedAt != null)
                      Text(
                        'Konum alındı: ${locatedAt!.hour.toString().padLeft(2, '0')}:${locatedAt!.minute.toString().padLeft(2, '0')}',
                      ),
                    if (coordinates!.accuracy > 50)
                      const Text(
                        'Konum hassasiyeti düşük. Kaydetmeden önce yeniden almayı deneyebilirsin.',
                      ),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                final opened = await ref
                                    .read(parkingLocationProvider)
                                    .openMap(
                                      ParkingPlace(
                                        indoor: false,
                                        savedAt: DateTime.now(),
                                        latitude: coordinates!.latitude,
                                        longitude: coordinates!.longitude,
                                        accuracy: coordinates!.accuracy,
                                      ),
                                    );
                                if (!opened && mounted) {
                                  setState(
                                    () => error =
                                        'Harita açılamadı. Tekrar dene.',
                                  );
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => error =
                                        'Harita açılamadı. Tekrar dene.',
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Google Haritalar’da kontrol et'),
                    ),
                  ],
                ] else ...[
                  field(
                    floor,
                    'Kat',
                    hint: 'Örn. -2, zemin, 3. kat',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  field(
                    section,
                    'Bölüm / harf',
                    hint: 'Örn. A, B, C',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  field(
                    space,
                    'Park yeri numarası (isteğe bağlı)',
                    hint: 'Örn. 125',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Otopark giriş konumu (isteğe bağlı). Kaydedersen aracına dönerken girişe rota açabilirsin.',
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : locate,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Otopark giriş konumunu al'),
                  ),
                  if (coordinates != null) ...[
                    ParkingMap(
                      latitude: coordinates!.latitude,
                      longitude: coordinates!.longitude,
                      label: 'Otopark giriş konumu',
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              coordinates = null;
                              locatedAt = null;
                            }),
                      child: const Text('Giriş konumunu kaldır'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: notes,
                  enabled: !busy,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Otopark adı / not (isteğe bağlı)',
                    hintText: 'Örn. AVM, asansörün yanı',
                  ),
                  validator: (v) => (v?.trim().length ?? 0) > 500
                      ? 'Not en fazla 500 karakter olabilir.'
                      : null,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Park yerini kaydet'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = false,
  }) => TextFormField(
    controller: controller,
    enabled: !busy,
    maxLength: 30,
    decoration: InputDecoration(labelText: label, hintText: hint),
    validator: (value) => required && (value?.trim().isEmpty ?? true)
        ? '$label bilgisini gir.'
        : (value?.trim().length ?? 0) > 30
        ? 'En fazla 30 karakter gir.'
        : null,
  );
}
