import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../services/car_map_icon.dart';
import '../services/google_maps_availability.dart';

final carMapIconProvider = FutureProvider<BitmapDescriptor>(
  (ref) async => BitmapDescriptor.bytes(
    await ref.watch(carMapImageProvider.future),
    width: 60,
    height: 60,
  ),
);
final googleMapViewProvider = Provider<Widget Function(GoogleMap)>(
  (ref) =>
      (map) => map,
);
final googleMapReadyProvider = Provider<bool>((ref) => googleMapsReady);

class GoogleParkingMap extends ConsumerStatefulWidget {
  const GoogleParkingMap({
    super.key,
    this.latitude,
    this.longitude,
    required this.label,
  });
  final double? latitude, longitude;
  final String label;
  @override
  ConsumerState<GoogleParkingMap> createState() => _GoogleParkingMapState();
}

class _GoogleParkingMapState extends ConsumerState<GoogleParkingMap> {
  GoogleMapController? controller;
  Timer? authCheck;
  bool failed = false;
  bool get hasPoint => widget.latitude != null && widget.longitude != null;
  LatLng get center => hasPoint
      ? LatLng(widget.latitude!, widget.longitude!)
      : const LatLng(39, 35);
  @override
  void initState() {
    super.initState();
    failed = !ref.read(googleMapReadyProvider) || googleMapsFailed;
    if (kIsWeb) {
      authCheck = Timer.periodic(const Duration(seconds: 1), (_) {
        if (googleMapsFailed && mounted && !failed) {
          setState(() => failed = true);
        }
      });
    }
  }

  void focus() {
    controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: hasPoint ? 17 : 5),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant GoogleParkingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      focus();
    }
  }

  @override
  void dispose() {
    authCheck?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = ref.watch(carMapIconProvider);
    return SizedBox(
      height: 250,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: failed
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Google Haritalar yüklenemedi. Bağlantını kontrol edip uygulamayı yeniden aç.',
                    ),
                  ),
                ),
              )
            : Stack(
                children: [
                  ref.watch(googleMapViewProvider)(
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: center,
                        zoom: hasPoint ? 17 : 5,
                      ),
                      onMapCreated: (value) {
                        if (!mounted) {
                          value.dispose();
                          return;
                        }
                        controller = value;
                        focus();
                      },
                      mapType: MapType.normal,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: true,
                      tiltGesturesEnabled: false,
                      markers: hasPoint && icon.hasValue
                          ? {
                              Marker(
                                markerId: const MarkerId('parked-car'),
                                position: center,
                                icon: icon.requireValue,
                                anchor: const Offset(0.5, 0.5),
                                infoWindow: InfoWindow(title: widget.label),
                              ),
                            }
                          : {},
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: hasPoint ? 56 : 8,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                  ),
                  if (hasPoint)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: PointerInterceptor(
                        child: IconButton.filledTonal(
                          tooltip: 'Park noktasına odaklan',
                          onPressed: focus,
                          icon: const Icon(Icons.directions_car_filled),
                        ),
                      ),
                    ),
                  if (icon.hasError && hasPoint)
                    const Positioned(
                      top: 52,
                      left: 8,
                      right: 8,
                      child: Text(
                        'Araç simgesi yüklenemedi. Yeniden açıp tekrar dene.',
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
