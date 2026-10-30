import 'package:my_car/features/inspection/repositories/inspection_repository.dart';
import 'support/fake_inspection_repository.dart';
import 'package:my_car/features/records/controllers/activity_controller.dart';
import 'support/fake_activity_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/app/app.dart';
import 'package:my_car/features/auth/controllers/auth_controller.dart';
import 'package:my_car/features/auth/models/app_user.dart';
import 'package:my_car/features/vehicles/controllers/vehicle_controller.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_vehicle_repository.dart';
import 'package:my_car/features/vehicles/models/vehicle.dart';

Widget app(FakeVehicleRepository repository) => ProviderScope(
  overrides: [
    inspectionRepositoryProvider.overrideWithValue(FakeInspectionRepository()),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(
        user: const AppUser(uid: 'test', email: 'test@example.com'),
      ),
    ),
    vehicleRepositoryProvider.overrideWithValue(repository),
  ],
  child: const MyCarApp(),
);
Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
}

Future<void> tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(DropdownButtonFormField<String>, label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.text(value).last;
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Marka değişiminde seri/model sıfırlanır; Mercedes E 250 seçilir',
    (tester) async {
      final repository = FakeVehicleRepository();
      await tester.pumpWidget(app(repository));
      await tester.pumpAndSettle();
      await tap(tester, 'İlk aracımı ekle');
      await choose(tester, 'Marka', 'BMW');
      await choose(tester, 'Seri', '3 Serisi');
      await choose(tester, 'Model', '330i');
      await choose(tester, 'Marka', 'Mercedes-Benz');
      final modelField = tester.widget<DropdownButtonFormField<String>>(
        find.widgetWithText(DropdownButtonFormField<String>, 'Model'),
      );
      expect(modelField.initialValue, isNull);
      await choose(tester, 'Seri', 'E Serisi');
      await choose(tester, 'Model', 'E 250');
      await fill(tester, 'Model yılı', '2015');
      await fill(tester, 'Plaka', '34 TEST 1');
      await fill(tester, 'Motor hacmi (cc)', '1991');
      await fill(tester, 'Güncel kilometre', '120000');
      await tap(tester, 'Aracı kaydet');
      expect(repository.vehicles.single.brand, 'Mercedes-Benz');
      expect(repository.vehicles.single.model, 'E 250');
    },
  );
  testWidgets('Katalog dışındaki eski araç bilgisi düzenlemede korunur', (
    tester,
  ) async {
    final repository = FakeVehicleRepository(
      seed: const [
        Vehicle(
          id: 'old',
          brand: 'Eski marka',
          model: 'Özel model',
          year: 2000,
          plate: '34 OLD 1',
          fuelType: 'Benzin',
          transmission: 'Manuel',
          currentKm: 100000,
        ),
      ],
    );
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tap(tester, 'Garaj');
    await tap(tester, 'Düzenle');
    expect(find.text('Eski marka'), findsOneWidget);
    expect(find.text('Özel model'), findsOneWidget);
    await tap(tester, 'Aracı kaydet');
    expect(repository.vehicles.single.model, 'Özel model');
  });
  testWidgets('İlk araç doğrulanır, kaydedilir, düzenlenir ve geri alınır', (
    tester,
  ) async {
    final repository = FakeVehicleRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Garajın seni bekliyor'), findsOneWidget);
    await tap(tester, 'İlk aracımı ekle');
    await tap(tester, 'Aracı kaydet');
    expect(repository.vehicles, isEmpty);
    await choose(tester, 'Marka', 'Toyota');
    await choose(tester, 'Model', 'Corolla');
    await fill(tester, 'Model yılı', '2021');
    await fill(tester, 'Plaka', '34 abc 123');
    await fill(tester, 'Motor hacmi (cc)', '1600');
    await fill(tester, 'Güncel kilometre', '67000');
    await tap(tester, 'Aracı kaydet');
    expect(find.text('Toyota Corolla'), findsOneWidget);
    expect(repository.vehicles.single.plate, '34 ABC 123');
    await tap(tester, 'Düzenle');
    await fill(tester, 'Güncel kilometre', '68000');
    await tap(tester, 'Aracı kaydet');
    expect(repository.vehicles.single.currentKm, 68000);
    await tap(tester, 'Kaldır');
    await tap(tester, 'Vazgeç');
    expect(repository.visible, hasLength(1));
    await tap(tester, 'Kaldır');
    await tap(tester, 'Kaldır');
    expect(repository.visible, isEmpty);
    await tap(tester, 'Geri al');
    expect(repository.visible, hasLength(1));
  });
  testWidgets('Kaydetme başarısız olduğunda başarı ekranına geçilmez', (
    tester,
  ) async {
    final repository = FakeVehicleRepository(seed: testVehicles)
      ..failure = 'Bağlantı kurulamadı.';
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tap(tester, 'Garaj');
    final edit = find.text('Düzenle').first;
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tap(tester, 'Aracı kaydet');
    expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
    expect(find.text('Aracı düzenle'), findsOneWidget);
  });
  testWidgets('Araç listesi hatası yeniden denenebilir', (tester) async {
    final repository = FakeVehicleRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    repository.changes.addError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Araçların yüklenemedi'), findsOneWidget);
    await tap(tester, 'Tekrar dene');
    expect(find.text('Garajın seni bekliyor'), findsOneWidget);
  });
}
