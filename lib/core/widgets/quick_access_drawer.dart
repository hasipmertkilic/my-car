import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/vehicles/controllers/vehicle_controller.dart';
import '../../features/records/controllers/activity_controller.dart';

class QuickAccessDrawer extends ConsumerWidget {
  const QuickAccessDrawer({super.key, required this.location});
  final String location;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final car = ref.watch(activeVehicleProvider);
    final ready =
        ref.watch(vehiclesProvider).hasValue &&
        ref.watch(activeVehicleIdProvider).hasValue;
    final id = ready ? car?.id : null;
    final t = Theme.of(context);
    final c = t.colorScheme;
    final offline =
        ref.watch(offlineRecordStateProvider).asData?.value?.online == false;
    void open(String path, {bool vehicle = false}) {
      if (offline && (path == '/stations' || path == '/journey')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rota ve istasyon araması için internet bağlantısı gerekiyor.',
            ),
          ),
        );
        return;
      }
      final target = vehicle && id == null ? '/garage' : path;
      final router = GoRouter.of(context);
      Navigator.pop(context);
      if (target.startsWith('/vehicles/') ||
          target == '/settings' ||
          target == '/stations' ||
          target == '/journey') {
        router.push(target);
      } else {
        router.go(target);
      }
    }

    Widget group(String title, List<(String, IconData, String, bool)> items) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  title,
                  style: t.textTheme.labelSmall?.copyWith(
                    color: c.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.7,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 280 ? 2 : 1;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final item in items)
                        SizedBox(
                          width: (box.maxWidth - (columns - 1) * 10) / columns,
                          child: Material(
                            color: location == item.$3
                                ? c.primaryContainer
                                : c.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => open(item.$3, vehicle: item.$4),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(item.$2, color: c.primary, size: 24),
                                    const SizedBox(height: 15),
                                    Text(
                                      item.$1,
                                      style: t.textTheme.labelLarge,
                                    ),
                                    if (item.$4 && id == null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Önce araç seç',
                                        style: t.textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
    return Drawer(
      width: math.min(460, MediaQuery.sizeOf(context).width * .94),
      semanticLabel: 'Hızlı erişim menüsü',
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hızlı erişim',
                      style: t.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hızlı erişimi kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      id == null
                          ? 'Garajından bir araç seçerek başla.'
                          : '${car!.name}\n${car.plate}',
                      style: t.textTheme.titleSmall?.copyWith(
                        color: c.onPrimaryContainer,
                      ),
                    ),
                  ),
                  group('GÜNLÜK KULLANIM', [
                    ('Ana ekran', Icons.grid_view_outlined, '/summary', false),
                    ('Rota oluştur', Icons.alt_route_rounded, '/journey', true),
                    ('Kayıtlarım', Icons.notes_rounded, '/records', false),
                    (
                      'Yakıt ekle',
                      Icons.local_gas_station_outlined,
                      '/vehicles/$id/fuel/new',
                      true,
                    ),
                    (
                      'Masraf ekle',
                      Icons.payments_outlined,
                      '/vehicles/$id/expense/new',
                      true,
                    ),
                    (
                      'Yakındaki istasyonlar',
                      Icons.near_me_outlined,
                      '/stations',
                      false,
                    ),
                    (
                      'İstatistikler',
                      Icons.insights_outlined,
                      '/statistics',
                      false,
                    ),
                  ]),
                  group('ARACININ DOSYASI', [
                    (
                      'Bakım takibi',
                      Icons.build_outlined,
                      '/vehicles/$id/maintenance',
                      true,
                    ),
                    (
                      'Araç ekspertizi',
                      Icons.fact_check_outlined,
                      '/vehicles/$id/expertise',
                      true,
                    ),
                    (
                      'Sigorta ve kasko poliçeleri',
                      Icons.shield_outlined,
                      '/vehicles/$id/policies',
                      true,
                    ),
                    (
                      'Muayene takibi',
                      Icons.event_available_outlined,
                      '/vehicles/$id/inspection',
                      true,
                    ),
                  ]),
                  group('PARK VE GARAJ', [
                    (
                      'Park yerim',
                      Icons.local_parking_outlined,
                      '/parking',
                      false,
                    ),
                    (
                      'Park yeri kaydet',
                      Icons.add_location_alt_outlined,
                      '/vehicles/$id/parking',
                      true,
                    ),
                    (
                      'Önceki park yerlerim',
                      Icons.history_rounded,
                      '/vehicles/$id/parking/history',
                      true,
                    ),
                    (
                      'Garajım / araç değiştir',
                      Icons.directions_car_outlined,
                      '/garage',
                      false,
                    ),
                    (
                      'Araç ekle',
                      Icons.add_circle_outline,
                      '/vehicles/new',
                      false,
                    ),
                    (
                      'Ayarlar ve hesabım',
                      Icons.tune_rounded,
                      '/settings',
                      false,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
