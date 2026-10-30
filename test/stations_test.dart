import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_car/features/stations/station_service.dart';
import 'package:my_car/features/stations/stations_screen.dart';
import 'package:my_car/features/stations/station_map_icons.dart';
import 'package:my_car/features/stations/station_brand.dart';
import 'package:my_car/features/parking/widgets/google_parking_map.dart';
import 'package:my_car/features/parking/services/parking_location.dart';
import 'parking_test.dart' show FakeLocation;

void main() {
  test(
    'Station names match explicit brands without substring or ambiguous matches',
    () {
      expect(stationBrandAsset('Shell Atakent'), endsWith('/shell.png'));
      expect(
        stationBrandAsset('OPET / Aygaz - İstanbul'),
        endsWith('/opet.png'),
      );
      expect(
        stationBrandAsset('PETROL OFİSİ Merkez'),
        endsWith('/petrol_ofisi.png'),
      );
      expect(stationBrandAsset('BP Akaryakıt'), endsWith('/bp.png'));
      expect(
        stationBrandAsset('TotalEnergies Ataşehir'),
        endsWith('/totalenergies.png'),
      );
      expect(
        stationBrandAsset('Total Energies Merkez'),
        endsWith('/totalenergies.png'),
      );
      expect(stationBrandAsset('Bpet Akaryakıt'), isNull);
      expect(stationBrandAsset('Bağımsız Petrol'), isNull);
      expect(stationBrandAsset('Shell Opet Servis'), isNull);
    },
  );
  test('Signed-in request sends coordinates and parses stations', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer session-token');
      expect(jsonDecode(request.body)['data'], {
        'latitude': 41.0,
        'longitude': 29.0,
      });
      return http.Response(
        jsonEncode({
          'result': {
            'stations': [
              {
                'id': 'one',
                'name': 'Örnek istasyon',
                'address': 'İstanbul',
                'latitude': 41,
                'longitude': 29,
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final stations = await StationService(
      client,
      () async => 'session-token',
    ).nearby(41, 29);
    expect(stations.single.name, 'Örnek istasyon');
    expect(
      stations.single.directions.queryParameters['destination_place_id'],
      'one',
    );
    expect(stations.single.directions.queryParameters['origin'], isNull);
  });
  test(
    'Missing session, unavailable service and limits return useful errors',
    () async {
      final client = MockClient((_) async => http.Response('{}', 404));
      await expectLater(
        StationService(client, () async => null).nearby(41, 29),
        throwsA(isA<StationFailure>()),
      );
      await expectLater(
        StationService(client, () async => 'token').nearby(41, 29),
        throwsA(isA<StationFailure>()),
      );
      final limited = MockClient(
        (_) async =>
            http.Response('{"error":{"status":"RESOURCE_EXHAUSTED"}}', 429),
      );
      await expectLater(
        StationService(limited, () async => 'token').nearby(41, 29),
        throwsA(
          isA<StationFailure>().having(
            (e) => e.message,
            'message',
            contains('bekleyip'),
          ),
        ),
      );
    },
  );
  testWidgets(
    'Location is requested on tap; results appear as map markers and list',
    (tester) async {
      final location = FakeLocation();
      GoogleMap? map;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stationBubbleProvider.overrideWith(
              (ref, label) async => StationBubbleIcons(
                BitmapDescriptor.defaultMarker,
                BitmapDescriptor.defaultMarker,
              ),
            ),
            // These providers isolate platform location and maps in the widget test.
            parkingLocationProvider.overrideWithValue(location),
            stationMapIconsProvider.overrideWith(
              (ref) async => StationMapIcons(
                BitmapDescriptor.defaultMarker,
                BitmapDescriptor.defaultMarker,
                BitmapDescriptor.defaultMarker,
              ),
            ),
            googleMapReadyProvider.overrideWithValue(true),
            googleMapViewProvider.overrideWithValue((value) {
              map = value;
              return const SizedBox();
            }),
            stationServiceProvider.overrideWithValue(
              StationService(
                MockClient(
                  (_) async => http.Response(
                    jsonEncode({
                      'result': {
                        'stations': [
                          {
                            'id': 'one',
                            'name': 'Deneme istasyonu',
                            'address': 'İstanbul',
                            'latitude': 41.01,
                            'longitude': 28.98,
                          },
                        ],
                      },
                    }),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  ),
                ),
                () async => 'token',
              ),
            ),
          ],
          child: const MaterialApp(home: StationsScreen()),
        ),
      );
      expect(location.calls, 0);
      await tester.tap(find.text('Konumumdan istasyon bul'));
      await tester.pumpAndSettle();
      expect(location.calls, 1);
      expect(map!.markers.length, 2);
      await tester.ensureVisible(find.text('Deneme istasyonu'));
      await tester.tap(find.text('Deneme istasyonu'));
      await tester.pumpAndSettle();
      expect(find.text('SEÇİLEN İSTASYON'), findsOneWidget);
      expect(find.text('Yol tarifi al'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Permission rejection is recoverable without contacting Places', (
    tester,
  ) async {
    final location = FakeLocation()..failure = 'Konum izni verilmedi.';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stationBubbleProvider.overrideWith(
            (ref, label) async => StationBubbleIcons(
              BitmapDescriptor.defaultMarker,
              BitmapDescriptor.defaultMarker,
            ),
          ),
          parkingLocationProvider.overrideWithValue(location),
          stationMapIconsProvider.overrideWith(
            (ref) async => StationMapIcons(
              BitmapDescriptor.defaultMarker,
              BitmapDescriptor.defaultMarker,
              BitmapDescriptor.defaultMarker,
            ),
          ),
        ],
        child: const MaterialApp(home: StationsScreen()),
      ),
    );
    await tester.tap(find.text('Konumumdan istasyon bul'));
    await tester.pumpAndSettle();
    expect(find.text('Konum izni verilmedi.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
