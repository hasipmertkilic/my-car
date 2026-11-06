import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../parking/widgets/google_parking_map.dart';
import 'journey_models.dart';
import 'eds_data.dart';

class JourneyRouteMap extends ConsumerStatefulWidget {
  const JourneyRouteMap({
    super.key,
    required this.route,
    this.eds = const [],
    this.edsIcon,
    this.onEdsTap,
  });
  final JourneyRoute route;
  final List<RouteEdsPoint> eds;
  final BitmapDescriptor? edsIcon;
  final void Function(RouteEdsPoint)? onEdsTap;
  @override
  ConsumerState<JourneyRouteMap> createState() => _JourneyRouteMapState();
}

class _JourneyRouteMapState extends ConsumerState<JourneyRouteMap> {
  GoogleMapController? controller;
  void fit() {
    if (controller == null) return;
    final points = widget.route.points;
    var south = points.first.latitude,
        north = south,
        west = points.first.longitude,
        east = west;
    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    controller!
        .animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(south - .001, west - .001),
              northeast: LatLng(north + .001, east + .001),
            ),
            40,
          ),
        )
        .catchError((_) {});
  }

  @override
  void didUpdateWidget(covariant JourneyRouteMap old) {
    super.didUpdateWidget(old);
    if (old.route.polyline != widget.route.polyline) fit();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(googleMapReadyProvider)) return const _MapUnavailable();
    final route = widget.route;
    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ref.watch(googleMapViewProvider)(
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(route.start.latitude, route.start.longitude),
              zoom: 8,
            ),
            onMapCreated: (value) {
              if (!mounted) {
                value.dispose();
                return;
              }
              controller = value;
              fit();
            },
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: true,
            polylines: {
              Polyline(
                polylineId: const PolylineId('journey'),
                color: Theme.of(context).colorScheme.primary,
                width: 5,
                points: route.points
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
              ),
            },
            markers: {
              for (final match in widget.eds)
                Marker(
                  markerId: MarkerId('eds-${match.point.id}'),
                  position: LatLng(
                    match.point.position.latitude,
                    match.point.position.longitude,
                  ),
                  anchor: const Offset(.5, .5),
                  icon:
                      widget.edsIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                  onTap: () => widget.onEdsTap?.call(match),
                ),
              Marker(
                markerId: const MarkerId('origin'),
                position: LatLng(route.start.latitude, route.start.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                infoWindow: const InfoWindow(title: 'Başlangıç'),
              ),
              Marker(
                markerId: const MarkerId('destination'),
                position: LatLng(route.end.latitude, route.end.longitude),
                infoWindow: const InfoWindow(title: 'Varış'),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class JourneyPointPicker extends ConsumerStatefulWidget {
  const JourneyPointPicker({super.key, required this.title, this.initial});
  final String title;
  final JourneyPoint? initial;
  @override
  ConsumerState<JourneyPointPicker> createState() => _JourneyPointPickerState();
}

class _JourneyPointPickerState extends ConsumerState<JourneyPointPicker> {
  JourneyPoint? point;
  @override
  void initState() {
    super.initState();
    point = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(googleMapReadyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Haritada istediğin noktaya dokun, sonra seçimini onayla.',
            ),
          ),
          Expanded(
            child: !ready
                ? const _MapUnavailable()
                : ref.watch(googleMapViewProvider)(
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          point?.latitude ?? 39,
                          point?.longitude ?? 35,
                        ),
                        zoom: point == null ? 5 : 14,
                      ),
                      onTap: (value) => setState(
                        () => point = JourneyPoint(
                          value.latitude,
                          value.longitude,
                        ),
                      ),
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      markers: point == null
                          ? {}
                          : {
                              Marker(
                                markerId: const MarkerId('chosen'),
                                position: LatLng(
                                  point!.latitude,
                                  point!.longitude,
                                ),
                              ),
                            },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton.icon(
                onPressed: !ready || point == null
                    ? null
                    : () => Navigator.pop(context, point),
                icon: const Icon(Icons.check),
                label: const Text('Konumu seç'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: Text(
        'Harita bu cihazda hazır değil. Başlangıç ve varışı adres yazarak seçebilirsin.',
      ),
    ),
  );
}
