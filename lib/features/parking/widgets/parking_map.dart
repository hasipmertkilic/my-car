import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/google_maps_availability.dart';
import 'google_parking_map.dart';
import '../services/car_map_icon.dart';

final googleMapsEnabledProvider = Provider<bool>((ref) => googleMapsRequested);

class ParkingMap extends ConsumerWidget {
  const ParkingMap({
    super.key,
    this.latitude,
    this.longitude,
    this.label = 'Park noktası',
  });
  final double? latitude, longitude;
  final String label;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(googleMapsEnabledProvider)
      ? GoogleParkingMap(latitude: latitude, longitude: longitude, label: label)
      : _OpenStreetParkingMap(
          latitude: latitude,
          longitude: longitude,
          label: label,
        );
}

final parkingTileProvider = Provider<TileProvider Function()>(
  (ref) =>
      () => NetworkTileProvider(),
);

class _OpenStreetParkingMap extends ConsumerStatefulWidget {
  const _OpenStreetParkingMap({
    this.latitude,
    this.longitude,
    this.label = 'Park noktası',
  });
  final double? latitude, longitude;
  final String label;
  @override
  ConsumerState<_OpenStreetParkingMap> createState() => _ParkingMapState();
}

class _ParkingMapState extends ConsumerState<_OpenStreetParkingMap> {
  final controller = MapController();
  bool ready = false, failed = false;
  int retry = 0;
  late TileProvider tiles;
  @override
  void initState() {
    super.initState();
    tiles = ref.read(parkingTileProvider)();
  }

  LatLng get center => widget.latitude != null && widget.longitude != null
      ? LatLng(widget.latitude!, widget.longitude!)
      : const LatLng(39, 35);
  bool get hasPoint => widget.latitude != null && widget.longitude != null;
  @override
  void didUpdateWidget(covariant _OpenStreetParkingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ready &&
        (oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude)) {
      controller.move(center, hasPoint ? 17 : 5);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 250,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: hasPoint ? 17 : 5,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () => ready = true,
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              TileLayer(
                key: ValueKey(retry),
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mertkilic.mycar',
                maxNativeZoom: 19,
                panBuffer: 0,
                tileProvider: tiles,
                errorTileCallback: (_, _, _) {
                  if (!failed && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => failed = true);
                    });
                  }
                },
              ),
              if (hasPoint)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: Semantics(
                        label: widget.label,
                        child: ref
                            .watch(carMapImageProvider)
                            .when(
                              data: (bytes) =>
                                  Image.memory(bytes, width: 60, height: 60),
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const Icon(
                                Icons.directions_car_filled,
                                color: Colors.orange,
                                size: 40,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              SimpleAttributionWidget(
                source: const Text(
                  'OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10),
                ),
                onTap: () async {
                  await launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 54,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasPoint
                      ? widget.label
                      : 'Konumunu alarak park noktasını göster',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          if (hasPoint)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Park noktasına odaklan',
                onPressed: () => controller.move(center, 17),
                icon: const Icon(Icons.center_focus_strong),
              ),
            ),
          if (failed)
            Positioned(
              bottom: 28,
              left: 8,
              right: 8,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  title: const Text(
                    'Harita yüklenemedi. İnternet bağlantını kontrol et.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Haritayı tekrar yükle',
                    onPressed: () => setState(() {
                      failed = false;
                      retry++;
                      tiles = ref.read(parkingTileProvider)();
                    }),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
