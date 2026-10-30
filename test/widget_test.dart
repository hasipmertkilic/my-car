import 'package:my_car/features/expertise/expertise_repository.dart';
import 'package:my_car/features/inspection/services/reminder_manager.dart';
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
import 'support/fake_auth_repository.dart';
import 'support/fake_vehicle_repository.dart';
import 'package:my_car/features/vehicles/controllers/vehicle_controller.dart';
import 'package:my_car/core/widgets/metric_card.dart';
import 'package:my_car/features/maintenance/maintenance_repository.dart';

Widget authenticatedApp({
  FakeVehicleRepository? vehicles,
  MaintenanceRepository? maintenance,
  ExpertiseRepository? expertise,
  ReminderManager? reminders,
}) => ProviderScope(
  overrides: [
    if (expertise != null)
      expertiseRepositoryProvider.overrideWithValue(expertise),
    if (reminders != null) reminderManagerProvider.overrideWithValue(reminders),
    if (maintenance != null)
      maintenanceRepositoryProvider.overrideWithValue(maintenance),
    inspectionRepositoryProvider.overrideWithValue(FakeInspectionRepository()),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
    vehicleRepositoryProvider.overrideWithValue(
      vehicles ?? FakeVehicleRepository(seed: testVehicles),
    ),
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(
        user: const AppUser(uid: 'test', email: 'test@example.com'),
      ),
    ),
  ],
  child: const MyCarApp(),
);

void main() {
  testWidgets('Özet başlığından araç seçilir; kayıt hatasında seçim korunur', (
    tester,
  ) async {
    final vehicles = FakeVehicleRepository(seed: testVehicles);
    await tester.pumpWidget(authenticatedApp(vehicles: vehicles));
    await tester.pumpAndSettle();
    final expense = tester.getSize(
      find.widgetWithText(MetricCard, 'Bu ayki gider'),
    );
    final fuel = tester.getSize(
      find.widgetWithText(MetricCard, 'Ortalama tüketim'),
    );
    expect(expense, fuel);
    await tester.tap(find.byTooltip('Araç seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renault Clio'));
    await tester.pumpAndSettle();
    expect(vehicles.activeId, 'clio');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Renault Clio'), findsOneWidget);
    vehicles.failure = 'Bağlantı kesildi.';
    await tester.tap(find.byTooltip('Araç seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BMW 320i'));
    await tester.pumpAndSettle();
    expect(find.text('Bağlantı kesildi.'), findsOneWidget);
    expect(vehicles.activeId, 'clio');
    expect(find.byType(BottomSheet), findsOneWidget);
  });
  testWidgets('Sade özette ekleme kartları yoktur; park geçmişi açılır', (
    tester,
  ) async {
    await tester.pumpWidget(authenticatedApp());
    await tester.pumpAndSettle();
    expect(find.text('Araç geçmişi'), findsOneWidget);
    for (final label in [
      'Yakıt ekle',
      'Masraf ekle',
      'Poliçelerim',
      'Park yeri kaydet',
      'Garajı yönet',
    ]) {
      expect(find.text(label), findsNothing);
    }
    await tester.ensureVisible(find.text('Park yerlerim'));
    await tester.tap(find.text('Park yerlerim'));
    await tester.pumpAndSettle();
    expect(find.text('Park yerlerim'), findsOneWidget);
    expect(find.text('BMW 320i'), findsOneWidget);
    expect(find.textContaining('Henüz park geçmişin yok.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Hızlı erişim açılır, kapanır ve seçili aracın poliçelerini açar',
    (tester) async {
      await tester.pumpWidget(authenticatedApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hızlı erişimi aç'));
      await tester.pumpAndSettle();
      expect(find.text('Hızlı erişim'), findsOneWidget);
      await tester.tap(find.byTooltip('Hızlı erişimi kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Hızlı erişim'), findsNothing);
      await tester.tap(find.text('Garaj'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bu aracı seç'));
      await tester.tap(find.text('Bu aracı seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hızlı erişimi aç'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Renault Clio\n'), findsOneWidget);
      final drawerScroll = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Sigorta ve kasko poliçeleri'),
        200,
        scrollable: drawerScroll,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sigorta ve kasko poliçeleri'));
      await tester.pumpAndSettle();
      expect(find.text('Poliçelerim'), findsOneWidget);
      expect(find.text('Renault Clio'), findsOneWidget);
      expect(find.text('Hızlı erişim'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Gezinme ve araç seçimi ekranlara yansır', (tester) async {
    await tester.pumpWidget(authenticatedApp());
    await tester.pumpAndSettle();
    expect(find.text('BMW 320i'), findsOneWidget);
    expect(find.textContaining('kişisel hesabına kaydedilir'), findsOneWidget);
    await tester.tap(find.text('Garaj'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bu aracı seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu aracı seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özet'));
    await tester.pumpAndSettle();
    expect(find.text('Renault Clio'), findsOneWidget);
    expect(find.text('48.200 km'), findsOneWidget);
    await tester.tap(find.text('Kayıtlar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Renault Clio'), findsOneWidget);
    expect(find.text('Henüz işlem kaydı yok.'), findsOneWidget);
    await tester.tap(find.text('İstatistikler'));
    await tester.pumpAndSettle();
    expect(find.text('Güncel kilometre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tema seçimi ve ayarlardan dönüş çalışır', (tester) async {
    await tester.pumpWidget(authenticatedApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koyu tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Açık tema').last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Görünüm'))).brightness,
      Brightness.light,
    );
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Yola hazır mısın?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Dar ekranda büyük yazı ile özet taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(authenticatedApp());
    await tester.pumpAndSettle();
    expect(find.text('BMW 320i'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('My Car'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
