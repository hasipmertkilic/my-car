import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'quick_access_drawer.dart';
import '../../features/records/widgets/offline_status_bar.dart';
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
  static const labels = ['Özet', 'Kayıtlar', 'Analiz', 'Park', 'Garaj'];
  static const icons = [
    Icons.grid_view_outlined,
    Icons.notes_rounded,
    Icons.stacked_line_chart_rounded,
    Icons.local_parking_rounded,
    Icons.directions_car_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final current = paths.indexOf(location);
    final selected = current < 0 ? 0 : current;
    final c = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final wordmark = Text(
      'My Car',
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: 1,
        color: c.onSurface,
      ),
    );
    return Scaffold(
      drawer: QuickAccessDrawer(location: location),
      appBar: AppBar(
        leadingWidth: 64,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Center(
              child: IconButton.outlined(
                tooltip: 'Hızlı erişimi aç',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 21),
                style: IconButton.styleFrom(
                  side: BorderSide(color: c.outlineVariant),
                ),
              ),
            ),
          ),
        ),
        title: location == '/summary'
            ? Tooltip(
                message: 'Araç seç',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => showVehiclePicker(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: wordmark),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: c.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : wordmark,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: IconButton.filledTonal(
              tooltip: 'Ayarlar',
              onPressed: () => context.push('/settings'),
              style: IconButton.styleFrom(backgroundColor: c.primaryContainer),
              icon: Icon(
                Icons.person_outline_rounded,
                color: c.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineStatusBar(),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 0, 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: NavigationRail(
                            extended: true,
                            minExtendedWidth: 176,
                            selectedIndex: selected,
                            onDestinationSelected: (i) => context.go(paths[i]),
                            destinations: [
                              for (var i = 0; i < paths.length; i++)
                                NavigationRailDestination(
                                  icon: Icon(icons[i], size: 22),
                                  label: Text(labels[i]),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  )
                : child,
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: c.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow.withValues(alpha: .06),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: (i) => context.go(paths[i]),
                    destinations: [
                      for (var i = 0; i < paths.length; i++)
                        NavigationDestination(
                          icon: Icon(icons[i], size: 22),
                          label: labels[i],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
