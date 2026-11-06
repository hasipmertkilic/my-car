import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'eds_data.dart';
import 'journey_models.dart';

RouteEdsPoint? upcomingEds({
  required JourneyPoint location,
  required double accuracy,
  required List<JourneyPoint> route,
  required List<RouteEdsPoint> points,
  required Set<String> alerted,
}) {
  if (!location.valid || !accuracy.isFinite || accuracy < 0 || accuracy > 50) {
    return null;
  }
  final match = edsNearRoute(route, [
    EdsPoint(id: '', name: '', position: location),
  ], radiusMeters: 100).firstOrNull;
  if (match == null) return null;
  for (final point in points) {
    final ahead = point.routeKm - match.routeKm;
    if (ahead >= 0 &&
        ahead <= .5 &&
        !alerted.contains(point.point.id) &&
        Geolocator.distanceBetween(
              location.latitude,
              location.longitude,
              point.point.position.latitude,
              point.point.position.longitude,
            ) <=
            500) {
      return point;
    }
  }
  return null;
}

class EdsAlerts extends StatefulWidget {
  const EdsAlerts({super.key, required this.route, required this.points});
  final List<JourneyPoint> route;
  final List<RouteEdsPoint> points;

  @override
  State<EdsAlerts> createState() => _EdsAlertsState();
}

class _EdsAlertsState extends State<EdsAlerts> with WidgetsBindingObserver {
  StreamSubscription<Position>? subscription;
  final alerted = <String>{};
  bool starting = false;
  String? message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(subscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (subscription != null &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      stop('Uygulama arka plana geçti; takip durduruldu.');
    }
  }

  void stop([String? reason]) {
    unawaited(subscription?.cancel());
    setState(() {
      subscription = null;
      message = reason;
    });
  }

  Future<void> start() async {
    setState(() {
      starting = true;
      message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) stop('Konum servisini açıp tekrar dene.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        stop('Konum izni verilmedi. Cihaz ayarlarını kontrol et.');
        return;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        stop('Takibi başlatmak için rota ekranına dön.');
        return;
      }
      alerted.clear();
      subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 15,
            ),
          ).listen(
            onPosition,
            onError: (Object error) {
              if (mounted) {
                stop('Konum takibi kesildi. Tekrar başlatabilirsin.');
              }
            },
            onDone: () {
              if (mounted) stop('Konum takibi sona erdi.');
            },
          );
    } catch (_) {
      if (mounted) stop('Konum takibi başlatılamadı.');
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  void onPosition(Position position) {
    if (!mounted ||
        subscription == null ||
        !TickerMode.valuesOf(context).enabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final next = upcomingEds(
      location: JourneyPoint(position.latitude, position.longitude),
      accuracy: position.accuracy,
      route: widget.route,
      points: widget.points,
      alerted: alerted,
    );
    if (next == null) return;
    alerted.add(next.point.id);
    const warning = 'Yakında EDS noktası olabilir. Yol levhalarını takip et.';
    setState(() => message = warning);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text(warning)));
    unawaited(HapticFeedback.vibrate());
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: starting
            ? null
            : subscription == null
            ? start
            : () => stop(),
        icon: Icon(
          subscription == null
              ? Icons.notifications_active_outlined
              : Icons.stop_circle_outlined,
        ),
        label: Text(
          starting
              ? 'Konum izni bekleniyor…'
              : subscription == null
              ? 'EDS uyarılarını başlat'
              : 'EDS uyarılarını durdur',
        ),
      ),
      const Text('Yaklaşık 500 m içinde uyarır. Rota ekranı açıkken çalışır.'),
      if (message != null) Text(message!),
    ],
  );
}
