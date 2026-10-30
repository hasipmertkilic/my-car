import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/page_content.dart';
import '../parking/services/parking_location.dart';
import '../parking/repositories/parking_repository.dart';
import '../parking/widgets/google_parking_map.dart';
import 'station_service.dart';
import 'station_map_icons.dart';
import 'station_brand.dart';

class StationsScreen extends ConsumerStatefulWidget {
  const StationsScreen({super.key});
  @override
  ConsumerState<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends ConsumerState<StationsScreen> {
  bool busy = false;
  String? error, selected;
  ParkCoordinates? point;
  List<FuelStation>? stations;
  GoogleMapController? controller;
  Future<void> search() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      stations = null;
      selected = null;
    });
    try {
      final position = await ref.read(parkingLocationProvider).locate();
      if (!mounted) return;
      setState(() => point = position);
      final results = await ref
          .read(stationServiceProvider)
          .nearby(position.latitude, position.longitude);
      results.sort(
        (a, b) =>
            Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              a.latitude,
              a.longitude,
            ).compareTo(
              Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                b.latitude,
                b.longitude,
              ),
            ),
      );
      if (!mounted) return;
      setState(() => stations = results);
    } on ParkingFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } on StationFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Arama tamamlanamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void select(FuelStation station) {
    setState(() => selected = station.id);
    controller?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(station.latitude, station.longitude),
        15,
      ),
    );
  }

  Future<void> navigate(FuelStation station) async {
    try {
      if (await launchUrl(
        station.directions,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      )) {
        return;
      }
    } catch (_) {
      /* Show the same recoverable message on launcher failure. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yol tarifi açılamadı. Tekrar dene.')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icons = ref.watch(stationMapIconsProvider).asData?.value;
    final colors = Theme.of(context).colorScheme;
    final current = point;
    final chosen = stations?.where((s) => s.id == selected).firstOrNull;
    String distance(FuelStation station) =>
        '${(Geolocator.distanceBetween(current!.latitude, current.longitude, station.latitude, station.longitude) / 1000).toStringAsFixed(1)} km';
    final bubbles = {
      if (current != null)
        for (final station in stations ?? <FuelStation>[])
          station.id: ref
              .watch(
                stationBubbleProvider((
                  name: station.name,
                  distance: distance(station),
                )),
              )
              .asData
              ?.value,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Yakındaki istasyonlar')),
      body: PageContent(
        children: [
          const SectionTitle(
            'Yakıt için yakında bir durak',
            subtitle:
                'Konumunun 5 km çevresindeki en yakın 20 istasyonu Google Haritalar üzerinde bul.',
          ),
          FilledButton.icon(
            onPressed: busy ? null : search,
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.near_me_outlined),
            label: Text(
              busy ? 'İstasyonlar aranıyor…' : 'Konumumdan istasyon bul',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Konumun yalnızca arama sırasında kullanılır. Yol tarifi Google Haritalar’da açılır.',
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                error!,
                semanticsLabel: error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (current != null && ref.watch(googleMapReadyProvider)) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * .8).clamp(
                520.0,
                760.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ref.watch(googleMapViewProvider)(
                  GoogleMap(
                    key: ValueKey('${current.latitude},${current.longitude}'),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(current.latitude, current.longitude),
                      zoom: 13,
                    ),
                    onMapCreated: (value) {
                      if (!mounted) {
                        value.dispose();
                        return;
                      }
                      controller = value;
                    },
                    mapToolbarEnabled: false,
                    style: Theme.of(context).brightness == Brightness.dark
                        ? _darkStationMapStyle
                        : null,
                    myLocationButtonEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('my-location'),
                        position: LatLng(current.latitude, current.longitude),
                        anchor: const Offset(.5, .5),
                        icon:
                            icons?.location ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ),
                        infoWindow: const InfoWindow(title: 'Arama konumun'),
                      ),
                      for (final station in stations ?? <FuelStation>[])
                        Marker(
                          markerId: MarkerId(station.id),
                          position: LatLng(station.latitude, station.longitude),
                          anchor: bubbles[station.id] == null
                              ? const Offset(.5, .5)
                              : const Offset(.5, 48 / 52),
                          zIndexInt: selected == station.id ? 2 : 1,
                          icon:
                              (selected == station.id
                                  ? bubbles[station.id]?.selected ??
                                        icons?.selected
                                  : bubbles[station.id]?.normal ??
                                        icons?.normal) ??
                              BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueOrange,
                              ),
                          consumeTapEvents: true,
                          onTap: () => select(station),
                        ),
                    },
                  ),
                ),
              ),
            ),
          ] else if (current != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Harita yüklenemedi. İstasyon listesinden yol tarifi alabilirsin.',
            ),
          ],
          if (chosen != null) ...[
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: colors.primary.withValues(alpha: .6)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: .16),
                      colors.surface,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        StationBrandBadge(name: chosen.name, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SEÇİLEN İSTASYON',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                chosen.name,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      chosen.address,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${distance(chosen)} • Kuş uçuşu mesafe',
                      style: TextStyle(
                        color: colors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => navigate(chosen),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Yol tarifi al'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (stations?.isEmpty ?? false)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '5 km çevrende istasyon bulunamadı. Başka bir konumda tekrar arayabilirsin.',
              ),
            ),
          if (stations != null && stations!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${stations!.length} istasyon • Mesafeler kuş uçuşudur',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final station in stations!)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 2.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: selected == station.id
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                ),
                child: ListTile(
                  selected: selected == station.id,
                  leading: StationBrandBadge(name: station.name, size: 28),
                  title: Text(station.name),
                  subtitle: Text('${station.address}\n${distance(station)}'),
                  isThreeLine: true,
                  onTap: () => select(station),
                  trailing: IconButton(
                    tooltip: 'Yol tarifi',
                    icon: const Icon(Icons.directions),
                    onPressed: () => navigate(station),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

const _darkStationMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#1e293b"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#cbd5e1"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0f172a"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#475569"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#64748b"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#12354a"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#1c3942"}]},
  {"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]''';
