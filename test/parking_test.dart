import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:my_car/features/parking/widgets/google_parking_map.dart';
import 'package:my_car/features/parking/services/car_map_icon.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_car/features/parking/widgets/parking_map.dart';
import 'package:my_car/features/parking/widgets/navigate_to_car_button.dart';
import 'package:my_car/features/parking/models/parking_place.dart';
import 'package:my_car/features/parking/repositories/parking_repository.dart';
import 'package:my_car/features/parking/screens/parking_screen.dart';
import 'package:my_car/features/parking/services/parking_location.dart';

class FakeParking implements ParkingRepository {
  @override
  Stream<List<ParkingPlace>> watchHistory(String id) => Stream.value([]);
  final places = <String, ParkingPlace>{};
  String? failure;
  @override
  Stream<ParkingPlace?> watch(String id) => Stream.value(places[id]);
  @override
  Future<void> save(String id, ParkingPlace place) async {
    if (failure != null) throw ParkingFailure(failure!);
    places[id] = place;
  }

  @override
  Future<void> finish(String id) async => places.remove(id);
}

class FakeLocation implements ParkingLocation {
  ParkingPlace? destination;
  bool opened = true;
  @override
  Future<bool> navigateToCar(ParkingPlace place) async {
    destination = place;
    return opened;
  }

  String? failure;
  int calls = 0;
  @override
  Future<ParkCoordinates> locate() async {
    calls++;
    if (failure != null) throw ParkingFailure(failure!);
    return const ParkCoordinates(41.01, 28.97, 12);
  }

  @override
  Future<bool> openMap(ParkingPlace place) async => true;
}

class TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

Future<void> startParking(
  WidgetTester tester,
  FakeParking repository,
  FakeLocation location,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const ParkingForm(vehicleId: 'bmw', name: 'BMW 320i'),
      ),
      GoRoute(
        path: '/summary',
        builder: (_, _) => const Scaffold(body: Text('Park kaydedildi')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        googleMapsEnabledProvider.overrideWithValue(false),
        parkingTileProvider.overrideWithValue(() => TestTiles()),
        parkingRepositoryProvider.overrideWithValue(repository),
        parkingLocationProvider.overrideWithValue(location),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Android varsayılan haritası Google ve işareti araba olur', (
    tester,
  ) async {
    final png = await tester.runAsync(createCarMapIcon);
    expect(png!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    final icon = google.BitmapDescriptor.bytes(png, width: 48, height: 48);
    final maps = <google.GoogleMap>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleMapReadyProvider.overrideWithValue(true),
          carMapIconProvider.overrideWith((ref) async => icon),
          googleMapViewProvider.overrideWithValue((map) {
            maps.add(map);
            return const SizedBox();
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ParkingMap(latitude: 41.01, longitude: 28.97)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final marker = maps.last.markers.single;
    expect(marker.position, const google.LatLng(41.01, 28.97));
    expect(marker.icon, same(icon));
    expect(marker.anchor, const Offset(0.5, 0.5));
    expect(find.byType(FlutterMap), findsNothing);
  });
  testWidgets(
    'Aracıma git kayıtlı noktayı kullanır; rota açılamazsa hata gösterir',
    (tester) async {
      final location = FakeLocation()..opened = false;
      final place = ParkingPlace(
        indoor: false,
        savedAt: DateTime(2026),
        latitude: 41.01,
        longitude: 28.97,
        accuracy: 12,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [parkingLocationProvider.overrideWithValue(location)],
          child: MaterialApp(
            home: Scaffold(body: NavigateToCarButton(place: place)),
          ),
        ),
      );
      await tester.tap(find.text('Aracıma git'));
      await tester.pumpAndSettle();
      expect(location.destination, same(place));
      expect(find.textContaining('Rota açılamadı.'), findsOneWidget);
      expect(place.directionsUrl.queryParameters['destination'], '41.01,28.97');
      expect(place.directionsUrl.queryParameters['origin'], isNull);
      expect(place.directionsUrl.queryParameters['travelmode'], 'walking');
      expect(place.directionsUrl.queryParameters['dir_action'], 'navigate');
    },
  );
  test('Koordinatlar doğrulanır ve harita kaydedilen noktayı açar', () {
    final place = ParkingPlace(
      indoor: false,
      savedAt: DateTime(2026),
      latitude: 41.01,
      longitude: 28.97,
      accuracy: 12,
    );
    expect(place.valid, isTrue);
    expect(place.mapUrl.queryParameters['query'], '41.01,28.97');
    expect(ParkingPlace.fromMap(place.toMap()).latitude, 41.01);
    expect(
      ParkingPlace(
        indoor: true,
        savedAt: DateTime(2026),
        floor: '-2',
        section: 'B',
        latitude: 41.01,
        longitude: 28.97,
        accuracy: 12,
      ).valid,
      isTrue,
    );
    expect(
      ParkingPlace(
        indoor: false,
        savedAt: DateTime(2026),
        latitude: 91,
        longitude: 28,
        accuracy: 12,
      ).valid,
      isFalse,
    );
    expect(
      ParkingPlace(
        indoor: true,
        savedAt: DateTime(2026),
        floor: '-2',
        section: 'B',
        latitude: 41,
      ).valid,
      isFalse,
    );
  });
  testWidgets('Kapalı otopark kat/bölüm ister ve konum izni kullanmaz', (
    tester,
  ) async {
    final repo = FakeParking();
    final location = FakeLocation();
    await startParking(tester, repo, location);
    await tester.tap(find.text('Kapalı otopark'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Park yerini kaydet'));
    await tester.tap(find.text('Park yerini kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Kat bilgisini gir.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Kat'), '-2');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bölüm / harf'),
      'b',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Park yeri numarası (isteğe bağlı)'),
      '125',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Park yerini kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Park yerini kaydet'));
    await tester.pumpAndSettle();
    expect(repo.places['bmw']!.description, 'Kat: -2 • Bölüm: B • Yer: 125');
    expect(repo.places['bmw']!.latitude, isNull);
    expect(location.calls, 0);
    expect(find.text('Park kaydedildi'), findsOneWidget);
  });
  testWidgets('Konum izni reddi ve kayıt hatası başarı sayfasına geçmez', (
    tester,
  ) async {
    final repo = FakeParking()..failure = 'Kaydedilemedi';
    final location = FakeLocation()..failure = 'Konum izni verilmedi';
    await startParking(tester, repo, location);
    await tester.tap(find.text('Konumumu al'));
    await tester.pumpAndSettle();
    expect(find.text('Konum izni verilmedi'), findsOneWidget);
    location.failure = null;
    await tester.tap(find.text('Konumumu al'));
    await tester.pumpAndSettle();
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markers.markers.single.point.latitude, 41.01);
    expect(markers.markers.single.point.longitude, 28.97);
    await tester.ensureVisible(find.text('Park yerini kaydet'));
    await tester.tap(find.text('Park yerini kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilemedi'), findsOneWidget);
    expect(find.text('Park kaydedildi'), findsNothing);
    repo.failure = null;
    await tester.tap(find.text('Park yerini kaydet'));
    await tester.pumpAndSettle();
    expect(repo.places['bmw']!.latitude, 41.01);
    expect(repo.places['bmw']!.valid, isTrue);
    expect(find.text('Park kaydedildi'), findsOneWidget);
  });
}
