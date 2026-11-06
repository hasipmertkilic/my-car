import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_car/features/journeys/journey_models.dart';
import 'package:my_car/features/journeys/journey_service.dart';
import 'widget_test.dart' show authenticatedApp;
import 'package:my_car/features/journeys/eds_data.dart';

void main() {
  testWidgets(
    'route menu opens and manual addresses return route alternatives',
    (tester) async {
      var calls = 0;
      final service = JourneyService(
        MockClient((request) async {
          calls++;
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          expect(data['origin'], {'address': 'İstanbul'});
          expect(data['destination'], {'address': 'Ankara'});
          return http.Response(
            jsonEncode({
              'result': {
                'routes': [
                  {
                    'id': 'a',
                    'name': 'Test route',
                    'distanceMeters': 450000,
                    'durationSeconds': 18000,
                    'polyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                    'start': {'latitude': 38.5, 'longitude': -120.2},
                    'end': {'latitude': 43.252, 'longitude': -126.453},
                  },
                ],
              },
            }),
            200,
          );
        }),
        () async => 'token',
      );
      await tester.pumpWidget(
        authenticatedApp(
          journeys: service,
          eds: EdsDataset(retrievedAt: DateTime(2026, 11, 3), points: const []),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hızlı erişimi aç'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Rota oluştur'));
      await tester.tap(find.text('Rota oluştur'));
      await tester.pumpAndSettle();
      expect(find.text('Bugün yolculuk nereye?'), findsOneWidget);
      expect(calls, 0);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'İstanbul');
      await tester.enterText(find.byType(TextFormField).at(1), 'Ankara');
      await tester.ensureVisible(find.text('Rotaları bul'));
      await tester.tap(find.text('Rotaları bul'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Test route'));
      expect(find.text('Test route'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test('fuel calculation keeps unknown toll separate from explicit zero', () {
    JourneyBudget budget(int? toll) =>
        JourneyBudget(km: 450, consumption: 8, unitPrice: 50, tollKurus: toll);
    expect(budget(null).units, 36);
    expect(budget(null).fuelKurus, 180000);
    expect(budget(null).totalKurus, isNull);
    expect(budget(0).totalKurus, 180000);
    expect(budget(10000).totalKurus, 190000);
  });
  test('polyline decodes coordinates and rejects truncated input', () {
    final points = decodeRoutePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points.length, 3);
    expect(points.first.latitude, 38.5);
    expect(points.last.longitude, closeTo(-126.453, .00001));
    for (final invalid in ['', '_', '??', 'abc']) {
      expect(() => decodeRoutePolyline(invalid), throwsFormatException);
    }
  });
  test('authenticated service sends only basic route inputs', () async {
    final service = JourneyService(
      MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        expect(
          data.keys,
          unorderedEquals(['origin', 'destination', 'avoidTolls']),
        );
        expect(data['origin'], {'address': 'İstanbul'});
        return http.Response(
          jsonEncode({
            'result': {
              'routes': [
                {
                  'id': 'a',
                  'name': 'Rota',
                  'distanceMeters': 450000,
                  'durationSeconds': 18000,
                  'polyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                  'start': {'latitude': 38.5, 'longitude': -120.2},
                  'end': {'latitude': 43.252, 'longitude': -126.453},
                },
              ],
            },
          }),
          200,
        );
      }),
      () async => 'token',
    );
    final routes = await service.plan(
      const JourneyWaypoint.address('İstanbul'),
      const JourneyWaypoint.address('Ankara'),
      avoidTolls: true,
    );
    expect(routes.single.km, 450);
  });
  test(
    'missing session never calls backend and empty routes are an error',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{"result":{"routes":[]}}', 200);
      });
      Future<List<JourneyRoute>> search(JourneyService service) => service.plan(
        const JourneyWaypoint.address('İstanbul'),
        const JourneyWaypoint.address('Ankara'),
        avoidTolls: false,
      );
      await expectLater(
        search(JourneyService(client, () async => null)),
        throwsA(isA<JourneyFailure>()),
      );
      expect(calls, 0);
      await expectLater(
        search(JourneyService(client, () async => 'token')),
        throwsA(isA<JourneyFailure>()),
      );
      expect(calls, 1);
    },
  );
}
