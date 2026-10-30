import 'package:my_car/features/inspection/repositories/inspection_repository.dart';
import 'support/fake_inspection_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/app/app.dart';
import 'package:my_car/features/auth/controllers/auth_controller.dart';
import 'package:my_car/features/auth/models/app_user.dart';
import 'package:my_car/features/vehicles/controllers/vehicle_controller.dart';
import 'package:my_car/features/records/controllers/activity_controller.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_vehicle_repository.dart';
import 'support/fake_activity_repository.dart';
import 'package:my_car/features/records/services/fuel_receipt_importer.dart';

class FakeReceiptImporter implements FuelReceiptImporter {
  FuelReceiptFields? result;
  FuelReceiptSource? source;
  String? failure;
  @override
  Future<FuelReceiptFields?> read(FuelReceiptSource value) async {
    source = value;
    if (failure != null) throw FuelReceiptFailure(failure!);
    return result;
  }
}

Future<void> start(
  WidgetTester tester,
  FakeActivityRepository repository, {
  FuelReceiptImporter? receipt,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (receipt != null)
          fuelReceiptImporterProvider.overrideWithValue(receipt),
        inspectionRepositoryProvider.overrideWithValue(
          FakeInspectionRepository(),
        ),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            user: const AppUser(uid: 'test', email: 'test@example.com'),
          ),
        ),
        vehicleRepositoryProvider.overrideWithValue(
          FakeVehicleRepository(seed: testVehicles),
        ),
        activityRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MyCarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty &&
      (text == 'Yakıt ekle' || text == 'Masraf ekle')) {
    await tester.tap(find.byTooltip('Hızlı erişimi aç'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(text),
      180,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
  }
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  final finder = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, value);
  await tester.pump();
}

void main() {
  testWidgets(
    'Fiş onayından sonra litre/tutar dolar; kilometre ve depo korunur, kayıt elle yapılır',
    (tester) async {
      final repository = FakeActivityRepository();
      final reader = FakeReceiptImporter()
        ..result = const FuelReceiptFields(
          litersMilli: 42300,
          amountKurus: 211500,
        );
      await start(tester, repository, receipt: reader);
      await tap(tester, 'Yakıt ekle');
      await tap(tester, 'Fiş fotoğrafı çek');
      expect(reader.source, FuelReceiptSource.camera);
      expect(find.text('Fişten okunan bilgiler'), findsOneWidget);
      expect(repository.records, isEmpty);
      await tap(tester, 'Forma doldur');
      expect(find.widgetWithText(TextFormField, '2115,00'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '42,300'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(repository.records, isEmpty);
      await tap(tester, 'Kaydı kaydet');
      expect(repository.records['bmw']!.single.amountKurus, 211500);
      expect(repository.records['bmw']!.single.litersMilli, 42300);
      expect(
        repository.records['bmw']!.single.odometerKm,
        testVehicles.first.currentKm,
      );
    },
  );
  testWidgets('Fiş iptali ve okuma hatası mevcut değerleri korur', (
    tester,
  ) async {
    final repository = FakeActivityRepository();
    final reader = FakeReceiptImporter()
      ..result = const FuelReceiptFields(
        litersMilli: 30000,
        amountKurus: 150000,
      );
    await start(tester, repository, receipt: reader);
    await tap(tester, 'Yakıt ekle');
    await enter(tester, 'Toplam tutar (TL)', '800,50');
    await tester.ensureVisible(find.text('Fiş fotoğrafı seç'));
    await tap(tester, 'Fiş fotoğrafı seç');
    await tap(tester, 'Vazgeç');
    expect(find.widgetWithText(TextFormField, '800,50'), findsOneWidget);
    reader.failure = 'Fiş okunamadı';
    await tap(tester, 'Fiş fotoğrafı seç');
    expect(find.text('Fiş okunamadı'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '800,50'), findsOneWidget);
    expect(repository.records, isEmpty);
  });
  testWidgets(
    'Yakıt eklenir, litre fiyatı hesaplanır ve giderler güncellenir',
    (tester) async {
      final repository = FakeActivityRepository();
      await start(tester, repository);
      await tap(tester, 'Yakıt ekle');
      await enter(tester, 'Kilometre', '125430');
      await enter(tester, 'Toplam tutar (TL)', '2115,00');
      await enter(tester, 'Alınan yakıt (litre)', '42,3');
      final switchTile = find.byType(SwitchListTile);
      await tester.ensureVisible(switchTile);
      await tester.tap(switchTile);
      await tester.pumpAndSettle();
      expect(find.textContaining('Litre fiyatı:'), findsOneWidget);
      await tap(tester, 'Kaydı kaydet');
      expect(repository.records['bmw']!.single.litersMilli, 42300);
      expect(repository.records['bmw']!.single.amountKurus, 211500);
      expect(repository.records['bmw']!.single.fullTank, isTrue);
      expect(find.text('Benzin alımı'), findsOneWidget);
      await tap(tester, 'İstatistikler');
      expect(find.text('₺2.115,00'), findsWidgets);
    },
  );
  testWidgets(
    'Masraf düzenlenir, kaldırılır ve geri alınır; başka araca geçince görünmez',
    (tester) async {
      final repository = FakeActivityRepository();
      await start(tester, repository);
      await tap(tester, 'Masraf ekle');
      await enter(tester, 'Toplam tutar (TL)', '350,50');
      await enter(tester, 'Açıklama / not (isteğe bağlı)', 'Yıkama faturası');
      await tap(tester, 'Kaydı kaydet');
      expect(repository.records['bmw']!.single.amountKurus, 35050);
      await tap(tester, 'Düzenle');
      await enter(tester, 'Toplam tutar (TL)', '400,25');
      await tap(tester, 'Kaydı kaydet');
      expect(repository.records['bmw']!.single.amountKurus, 40025);
      await tap(tester, 'Kaldır');
      await tap(tester, 'Kaldır');
      expect(repository.records['bmw'], isEmpty);
      await tap(tester, 'Geri al');
      expect(repository.records['bmw'], hasLength(1));
      await tap(tester, 'Garaj');
      await tap(tester, 'Bu aracı seç');
      await tap(tester, 'Kayıtlar');
      expect(find.text('Yıkama faturası'), findsNothing);
      expect(find.text('Henüz işlem kaydı yok.'), findsOneWidget);
    },
  );
  testWidgets('Geçersiz tutar yazılmaz; sunucu hatasında form korunur', (
    tester,
  ) async {
    final repository = FakeActivityRepository()
      ..failure = 'Bağlantı kurulamadı.';
    await start(tester, repository);
    await tap(tester, 'Masraf ekle');
    await enter(tester, 'Toplam tutar (TL)', '-10');
    await tap(tester, 'Kaydı kaydet');
    expect(repository.records, isEmpty);
    await enter(tester, 'Toplam tutar (TL)', '100');
    await tap(tester, 'Kaydı kaydet');
    expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
    expect(find.text('Masraf ekle'), findsOneWidget);
  });
}
