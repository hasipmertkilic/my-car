import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_car/features/journeys/eds_data.dart';
import 'package:my_car/features/journeys/eds_section.dart';
import 'package:my_car/features/journeys/journey_models.dart';
import 'package:my_car/features/parking/widgets/google_parking_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('tr_TR'));
  const near = EdsPoint(
    id: 'near',
    name: 'Test EDS',
    position: JourneyPoint(40.0005, 29.05),
  );
  const earlier = EdsPoint(
    id: 'early',
    name: 'Önceki',
    position: JourneyPoint(40, 29.02),
  );
  const far = EdsPoint(
    id: 'far',
    name: 'Uzak',
    position: JourneyPoint(40.01, 29.05),
  );
  test(
    'matching uses route segments, bounds proximity, and orders by journey progress',
    () {
      final points = edsNearRoute(
        const [JourneyPoint(40, 29), JourneyPoint(40, 29.1)],
        const [near, far, earlier],
      );
      expect(points.map((p) => p.point.id), ['early', 'near']);
      expect(points.last.offsetMeters, closeTo(55.6, 1));
      expect(points.first.routeKm, lessThan(points.last.routeKm));
      expect(edsNearRoute(const [JourneyPoint(40, 29)], const [near]), isEmpty);
      expect(
        edsNearRoute(
          const [JourneyPoint(40, 29), JourneyPoint(40, 29)],
          const [far],
        ),
        isEmpty,
      );
      final reversed = edsNearRoute(
        const [JourneyPoint(40, 29.1), JourneyPoint(40, 29)],
        const [near, earlier],
      );
      expect(reversed.first.point.id, 'near');
    },
  );
  test(
    'bundled official snapshot is valid and contains no invented limits or corridors',
    () async {
      final text = await rootBundle.loadString('assets/eds/egm_points.json');
      final dataset = EdsDataset.decode(text);
      expect(dataset.points.length, greaterThan(1000));
      expect(
        dataset.points.map((p) => p.id).toSet().length,
        dataset.points.length,
      );
      expect(dataset.points.every((p) => p.position.valid), isTrue);
      expect(
        dataset.stale(dataset.retrievedAt.add(const Duration(days: 31))),
        isTrue,
      );
      expect(dataset.stale(dataset.retrievedAt), isFalse);
      final raw = jsonDecode(text) as Map;
      expect(raw['sourceUpdatedAt'], isNull);
      expect(
        (raw['points'] as List).every(
          (p) => !(p as Map).containsKey('speedLimit'),
        ),
        isTrue,
      );
    },
  );
  testWidgets(
    'EDS toggle removes markers, detail shows source and no asserted speed limit',
    (tester) async {
      GoogleMap? map;
      final route = JourneyRoute(
        id: 'a',
        name: 'Test',
        distanceMeters: 20000,
        durationSeconds: 1000,
        polyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
        start: const JourneyPoint(40, 29),
        end: const JourneyPoint(40, 29.1),
      );
      // Constructor-decoded geometry is replaced with a small deterministic test route.
      route.points
        ..clear()
        ..addAll(const [JourneyPoint(40, 29), JourneyPoint(40, 29.1)]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            edsDatasetProvider.overrideWith(
              (ref) async => EdsDataset(
                retrievedAt: DateTime(2026, 11, 3),
                points: const [near],
              ),
            ),
            edsCameraIconProvider.overrideWith(
              (ref) async => BitmapDescriptor.defaultMarker,
            ),
            googleMapReadyProvider.overrideWithValue(true),
            googleMapViewProvider.overrideWithValue((value) {
              map = value;
              return const SizedBox(height: 300);
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: JourneyEdsSection(route: route),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(map!.markers.map((m) => m.markerId.value), contains('eds-near'));
      map!.markers.firstWhere((m) => m.markerId.value == 'eds-near').onTap!();
      await tester.pumpAndSettle();
      expect(find.text('EDS noktası'), findsOneWidget);
      expect(
        find.textContaining(
          'Denetim türü ve hız sınırı kaynakta ayrıca doğrulanmadı',
        ),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        map!.markers.any((m) => m.markerId.value.startsWith('eds-')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
