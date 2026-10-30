import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/vehicle_controller.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';

Future<void> showVehiclePicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _VehiclePicker(),
    );

class _VehiclePicker extends ConsumerStatefulWidget {
  const _VehiclePicker();
  @override
  ConsumerState<_VehiclePicker> createState() => _VehiclePickerState();
}

class _VehiclePickerState extends ConsumerState<_VehiclePicker> {
  bool busy = false;
  String? error;
  Future<void> select(Vehicle vehicle) async {
    if (busy) return;
    if (ref.read(activeVehicleProvider)?.id == vehicle.id) {
      Navigator.pop(context);
      return;
    }
    final repository = ref.read(vehicleRepositoryProvider);
    if (repository == null) {
      setState(() => error = 'Hesap bağlantısı hazır değil. Tekrar dene.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.select(vehicle.id);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is VehicleFailure
              ? failure.message
              : 'Araç seçilemedi. Tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    final active = ref.watch(activeVehicleProvider);
    final activeId = ref.watch(activeVehicleIdProvider);
    final colors = Theme.of(context).colorScheme;
    void retry() {
      ref.invalidate(vehiclesProvider);
      ref.invalidate(activeVehicleIdProvider);
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Araç seç',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        const Text('Özette görmek istediğin aracını seç.'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Araç seçimini kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(error!, style: TextStyle(color: colors.error)),
              ),
            const Divider(height: 1),
            Expanded(
              child: vehicles.hasError || activeId.hasError
                  ? Center(
                      child: TextButton(
                        onPressed: retry,
                        child: const Text('Araçlar yüklenemedi. Tekrar dene'),
                      ),
                    )
                  : vehicles.isLoading || activeId.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : vehicles.requireValue.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Henüz kayıtlı aracın yok. İlk aracını ekleyerek başlayabilirsin.',
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: vehicles.requireValue.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final vehicle = vehicles.requireValue[index];
                        final selected = active?.id == vehicle.id;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected
                                  ? colors.primary
                                  : colors.outlineVariant,
                            ),
                          ),
                          child: ListTile(
                            enabled: !busy,
                            selected: selected,
                            leading: Icon(
                              Icons.directions_car_filled_rounded,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            title: Text(vehicle.name),
                            subtitle: Text(
                              '${vehicle.plate} • ${vehicle.year}',
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle,
                                    color: colors.primary,
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: () => select(vehicle),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push('/vehicles/new');
                      },
                icon: const Icon(Icons.add),
                label: const Text('Araç ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
