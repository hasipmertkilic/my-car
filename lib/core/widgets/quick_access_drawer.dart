import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/vehicles/controllers/vehicle_controller.dart';

class QuickAccessDrawer extends ConsumerWidget {
  const QuickAccessDrawer({super.key, required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(activeVehicleProvider);
    final ready =
        ref.watch(vehiclesProvider).hasValue &&
        ref.watch(activeVehicleIdProvider).hasValue;
    final id = ready ? vehicle?.id : null;
    void open(String path) {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      if (path.startsWith('/vehicles/') ||
          path == '/settings' ||
          path == '/stations') {
        router.push(path);
      } else {
        router.go(path);
      }
    }

    Widget link(
      String title,
      IconData icon,
      String path, {
      bool forVehicle = false,
    }) {
      final target = forVehicle && id == null ? '/garage' : path;
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: forVehicle && id == null
            ? const Text('Önce garajından bir araç seç')
            : null,
        selected: location == path,
        onTap: () => open(target),
      );
    }

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    return Drawer(
      semanticLabel: 'Hızlı erişim menüsü',
      width: math.min(360, MediaQuery.sizeOf(context).width * .9),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_filled),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hızlı erişim',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hızlı erişimi kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                    child: Text(
                      id == null
                          ? 'Garajından bir araç seçerek başla.'
                          : '${vehicle!.name}\n${vehicle.plate}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  heading('GENEL'),
                  link('Ana ekran', Icons.dashboard_outlined, '/summary'),
                  link(
                    'Garajım / araç değiştir',
                    Icons.directions_car_outlined,
                    '/garage',
                  ),
                  link('Araç ekle', Icons.add_circle_outline, '/vehicles/new'),
                  link('Kayıtlarım', Icons.receipt_long_outlined, '/records'),
                  link('İstatistikler', Icons.bar_chart_rounded, '/statistics'),
                  link(
                    'Yakındaki istasyonlar',
                    Icons.local_gas_station_outlined,
                    '/stations',
                  ),
                  heading('ARACIM İÇİN'),
                  link(
                    'Araç ekspertizi',
                    Icons.fact_check_outlined,
                    '/vehicles/$id/expertise',
                    forVehicle: true,
                  ),
                  link(
                    'Bakım takibi',
                    Icons.build_outlined,
                    '/vehicles/$id/maintenance',
                    forVehicle: true,
                  ),
                  link(
                    'Yakıt ekle',
                    Icons.local_gas_station_outlined,
                    '/vehicles/$id/fuel/new',
                    forVehicle: true,
                  ),
                  link(
                    'Masraf ekle',
                    Icons.payments_outlined,
                    '/vehicles/$id/expense/new',
                    forVehicle: true,
                  ),
                  link(
                    'Sigorta ve kasko poliçeleri',
                    Icons.shield_outlined,
                    '/vehicles/$id/policies',
                    forVehicle: true,
                  ),
                  link(
                    'Muayene takibi',
                    Icons.event_available_outlined,
                    '/vehicles/$id/inspection',
                    forVehicle: true,
                  ),
                  link('Park yerim', Icons.local_parking_outlined, '/parking'),
                  link(
                    'Park yeri kaydet',
                    Icons.add_location_alt_outlined,
                    '/vehicles/$id/parking',
                    forVehicle: true,
                  ),
                  link(
                    'Önceki park yerlerim',
                    Icons.history_rounded,
                    '/vehicles/$id/parking/history',
                    forVehicle: true,
                  ),
                  const Divider(height: 32),
                  link(
                    'Ayarlar ve hesabım',
                    Icons.settings_outlined,
                    '/settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
