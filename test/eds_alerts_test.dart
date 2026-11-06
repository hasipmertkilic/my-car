import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/journeys/eds_alerts.dart';
import 'package:my_car/features/journeys/eds_data.dart';
import 'package:my_car/features/journeys/journey_models.dart';

void main() {
  test('only alerts for a nearby point ahead with reliable GPS', () {
    const route = [JourneyPoint(40, 29), JourneyPoint(40, 29.1)];
    const camera = EdsPoint(
      id: 'camera',
      name: 'EDS',
      position: JourneyPoint(40, 29.05),
    );
    final points = edsNearRoute(route, [camera]);
    RouteEdsPoint? check(
      JourneyPoint position, {
      double accuracy = 10,
      Set<String> seen = const {},
    }) => upcomingEds(
      location: position,
      accuracy: accuracy,
      route: route,
      points: points,
      alerted: seen,
    );
    const approaching = JourneyPoint(40, 29.046);
    expect(check(approaching)?.point.id, camera.id);
    expect(check(approaching, seen: {camera.id}), isNull);
    expect(check(approaching, accuracy: 80), isNull);
    expect(check(const JourneyPoint(40, 29.054)), isNull);
    expect(check(const JourneyPoint(40.002, 29.047)), isNull);
    expect(check(const JourneyPoint(40, 29.03)), isNull);
  });
}
