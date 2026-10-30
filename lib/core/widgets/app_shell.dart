import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'quick_access_drawer.dart';
import '../../features/vehicles/widgets/vehicle_picker.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  static const paths = [
    '/summary',
    '/records',
    '/statistics',
    '/parking',
    '/garage',
  ];
  static const labels = ['Özet', 'Kayıtlar', 'İstatistikler', 'Park', 'Garaj'];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.bar_chart_rounded,
    Icons.local_parking_outlined,
    Icons.directions_car_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final selected = paths.indexOf(location);
    return Scaffold(
      drawer: QuickAccessDrawer(location: location),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Hızlı erişimi aç',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: location == '/summary'
            ? Tooltip(
                message: 'Araç seç',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showVehiclePicker(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car_filled),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'My Car',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
                ),
              )
            : const Row(
                children: [
                  Icon(Icons.directions_car_filled),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text('My Car', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Araçların kişisel hesabına kaydedilir',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) => context.go(paths[index]),
        destinations: List.generate(
          paths.length,
          (index) => NavigationDestination(
            icon: Icon(icons[index]),
            label: labels[index],
          ),
        ),
      ),
    );
  }
}
