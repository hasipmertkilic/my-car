import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'journey_models.dart';

const edsSourceUrl =
    'https://onlineislemler.egm.gov.tr/trafik/sayfalar/edsharita.aspx';

class EdsPoint {
  const EdsPoint({
    required this.id,
    required this.name,
    required this.position,
  });
  final String id, name;
  final JourneyPoint position;
}

class EdsDataset {
  const EdsDataset({required this.retrievedAt, required this.points});
  final DateTime retrievedAt;
  final List<EdsPoint> points;
  bool stale(DateTime now) => now.difference(retrievedAt).inDays > 30;
  factory EdsDataset.decode(String text) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (data['source'] != edsSourceUrl) {
      throw const FormatException('eds-source');
    }
    final seen = <String>{};
    final points = <EdsPoint>[];
    for (final raw in data['points'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final position = JourneyPoint.fromJson(row);
      final id = row['id'] as String, name = row['name'] as String;
      if (id.isEmpty || name.isEmpty || !seen.add(id)) continue;
      if (position.latitude < 35.5 ||
          position.latitude > 42.5 ||
          position.longitude < 25.5 ||
          position.longitude > 45) {
        continue;
      }
      points.add(EdsPoint(id: id, name: name, position: position));
    }
    return EdsDataset(
      retrievedAt: DateTime.parse(data['retrievedAt'] as String),
      points: points,
    );
  }
}

final edsDatasetProvider = FutureProvider<EdsDataset>(
  (ref) async => EdsDataset.decode(
    await rootBundle.loadString('assets/eds/egm_points.json'),
  ),
);

class RouteEdsPoint {
  const RouteEdsPoint(this.point, this.routeKm, this.offsetMeters);
  final EdsPoint point;
  final double routeKm, offsetMeters;
}

/// Proximity to the route geometry, NOT proof of the same road or direction.
/// Overview polylines and parallel roads make this an approximate match.
List<RouteEdsPoint> edsNearRoute(
  List<JourneyPoint> route,
  List<EdsPoint> points, {
  double radiusMeters = 150,
}) {
  if (route.length < 2 || !radiusMeters.isFinite || radiusMeters <= 0) {
    return [];
  }
  const metersPerDegree = 111195.0;
  final result = <RouteEdsPoint>[];
  for (final point in points) {
    final latitude = point.position.latitude;
    final scaleX = metersPerDegree * math.cos(latitude * math.pi / 180);
    var traveled = 0.0, closest = double.infinity, along = 0.0;
    for (var i = 1; i < route.length; i++) {
      final a = route[i - 1], b = route[i];
      final ax = (a.longitude - point.position.longitude) * scaleX;
      final ay = (a.latitude - latitude) * metersPerDegree;
      final dx = (b.longitude - a.longitude) * scaleX;
      final dy = (b.latitude - a.latitude) * metersPerDegree;
      final squared = dx * dx + dy * dy;
      final fraction = squared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / squared).clamp(0.0, 1.0);
      final x = ax + dx * fraction, y = ay + dy * fraction;
      final distance = math.sqrt(x * x + y * y), length = math.sqrt(squared);
      if (distance < closest) {
        closest = distance;
        along = traveled + fraction * length;
      }
      traveled += length;
    }
    if (closest <= radiusMeters) {
      result.add(RouteEdsPoint(point, along / 1000, closest));
    }
  }
  result.sort((a, b) => a.routeKm.compareTo(b.routeKm));
  return result;
}
