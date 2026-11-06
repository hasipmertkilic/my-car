class JourneyPoint {
  const JourneyPoint(this.latitude, this.longitude);
  final double latitude, longitude;
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
  factory JourneyPoint.fromJson(Map<String, dynamic> json) {
    final point = JourneyPoint(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    );
    if (!point.valid) throw const FormatException('invalid-point');
    return point;
  }
  String get coordinateText => '$latitude,$longitude';
}

class JourneyWaypoint {
  const JourneyWaypoint.address(String value) : address = value, point = null;
  const JourneyWaypoint.point(JourneyPoint value)
    : point = value,
      address = null;
  final String? address;
  final JourneyPoint? point;
  Map<String, dynamic> toJson() =>
      point?.toJson() ?? {'address': address!.trim()};
}

class JourneyRoute {
  JourneyRoute({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    required this.start,
    required this.end,
    this.recommended = false,
  }) : points = decodeRoutePolyline(polyline);
  final String id, name, polyline;
  final double distanceMeters;
  final int durationSeconds;
  final bool recommended;
  final JourneyPoint start, end;
  final List<JourneyPoint> points;
  double get km => distanceMeters / 1000;
  factory JourneyRoute.fromJson(Map<String, dynamic> data) {
    final distance = (data['distanceMeters'] as num).toDouble();
    final seconds = (data['durationSeconds'] as num).toInt();
    if (!distance.isFinite ||
        distance <= 0 ||
        distance > 50000000 ||
        seconds < 0 ||
        seconds > 31536000) {
      throw const FormatException('invalid-route');
    }
    return JourneyRoute(
      id: data['id'] as String,
      name: data['name'] as String,
      distanceMeters: distance,
      durationSeconds: seconds,
      polyline: data['polyline'] as String,
      start: JourneyPoint.fromJson(
        Map<String, dynamic>.from(data['start'] as Map),
      ),
      end: JourneyPoint.fromJson(Map<String, dynamic>.from(data['end'] as Map)),
      recommended: data['recommended'] == true,
    );
  }
}

List<JourneyPoint> decodeRoutePolyline(String encoded) {
  if (encoded.isEmpty || encoded.length > 200000) {
    throw const FormatException('invalid-polyline');
  }
  var index = 0, latitude = 0, longitude = 0;
  final points = <JourneyPoint>[];
  int read() {
    var result = 0, shift = 0;
    while (true) {
      if (index >= encoded.length || shift > 30) {
        throw const FormatException('invalid-polyline');
      }
      final value = encoded.codeUnitAt(index++) - 63;
      if (value < 0 || value > 63) {
        throw const FormatException('invalid-polyline');
      }
      result |= (value & 31) << shift;
      if (value < 32) break;
      shift += 5;
    }
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    latitude += read();
    longitude += read();
    final point = JourneyPoint(latitude / 100000, longitude / 100000);
    if (!point.valid) throw const FormatException('invalid-polyline');
    points.add(point);
  }
  if (points.length < 2) throw const FormatException('invalid-polyline');
  return points;
}

class JourneyBudget {
  JourneyBudget({
    required double km,
    required double consumption,
    required double unitPrice,
    int? tollKurus,
  }) : units = km * consumption / 100,
       fuelKurus = (km * consumption / 100 * unitPrice * 100).round(),
       tollKurus = tollKurus {
    if (!km.isFinite ||
        km < 0 ||
        !consumption.isFinite ||
        consumption <= 0 ||
        !unitPrice.isFinite ||
        unitPrice <= 0 ||
        (tollKurus != null && tollKurus < 0)) {
      throw ArgumentError('invalid-budget');
    }
  }
  final double units;
  final int fuelKurus;
  final int? tollKurus;
  int? get totalKurus => tollKurus == null ? null : fuelKurus + tollKurus!;
}
