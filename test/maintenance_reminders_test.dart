import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/maintenance/maintenance_entry.dart';
import 'package:my_car/features/maintenance/maintenance_reminders.dart';
import 'package:my_car/features/inspection/services/reminder_manager.dart';
import 'package:my_car/core/widgets/notification_open_host.dart';
import 'inspection_test.dart' show TestGateway;
import 'maintenance_test.dart' show FakeMaintenance;
import 'widget_test.dart' show authenticatedApp;

class RecordingGateway extends TestGateway {
  final titles = <String>[];
  final payloads = <String>[];
  @override
  Future<void> show(int id, String title, String body, String payload) async {
    titles.add(title);
    payloads.add(payload);
    await super.show(id, title, body, payload);
  }
}

void main() {
  final entry = MaintenanceEntry(
    id: 'service',
    date: DateTime(2026, 1, 1),
    odometerKm: 100000,
    items: ['engine_oil', 'oil_filter'],
  );
  MaintenanceReminder reminder(int km) =>
      MaintenanceReminder('bmw', 'BMW', km, entry);
  test(
    'İlk kontrolde 2000 km altındaysa telefon bildirimi gönderilir',
    () async {
      final gateway = RecordingGateway();
      final manager = MaintenanceReminderManager(
        gateway,
        MemoryReminderStore(),
      );
      addTearDown(manager.dispose);
      manager.synchronize('test', [reminder(108001)]);
      await manager.settled;
      await manager.setEnabled(true);
      expect(gateway.shown.length, 1);
      expect(gateway.titles.single, '10.000 km bakımınız yaklaşıyor');
      expect(
        notificationPath(gateway.payloads.single, 'test', {'bmw'}),
        '/vehicles/bmw/maintenance?latest=1',
      );
    },
  );
  test('2000 km threshold, permission, deduplication and cleanup', () async {
    final gateway = RecordingGateway();
    final manager = MaintenanceReminderManager(gateway, MemoryReminderStore());
    addTearDown(manager.dispose);
    manager.synchronize('test', [reminder(107999)]);
    await manager.settled;
    gateway.permission = false;
    expect(await manager.setEnabled(true), isFalse);
    expect(manager.enabled, isFalse);
    gateway.permission = true;
    expect(await manager.setEnabled(true), isTrue);
    expect(gateway.shown, isEmpty);
    manager.synchronize('test', [reminder(108000)]);
    await manager.settled;
    expect(gateway.titles.single, '10.000 km bakımınız yaklaşıyor');
    manager.synchronize('test', [reminder(109900)]);
    await manager.settled;
    expect(gateway.shown.length, 1);
    final restarted = MaintenanceReminderManager(gateway, manager.store);
    restarted.synchronize('test', [reminder(109900)]);
    await restarted.settled;
    expect(gateway.shown.length, 1);
    restarted.dispose();
    manager.synchronize('test', [reminder(110000)]);
    await manager.settled;
    expect(gateway.shown.length, 2);
    manager.synchronize('test', [
      MaintenanceReminder(
        'bmw',
        'BMW',
        110000,
        MaintenanceEntry(
          id: 'next',
          date: DateTime(2026, 2),
          odometerKm: 110000,
          items: ['battery'],
        ),
      ),
    ]);
    await manager.settled;
    expect(gateway.canceled, contains(gateway.shown.first));
    manager.synchronize('test', [reminder(108000)]);
    await manager.settled;
    expect(gateway.shown.length, 2);
    await manager.setEnabled(false);
    manager.synchronize(null, []);
    await manager.settled;
    expect(manager.enabled, isFalse);
    manager.synchronize('other', [reminder(108000)]);
    await manager.settled;
    expect(gateway.shown.length, 2);
  });
  test('Notification routes validate account and owned vehicle', () {
    final payload = jsonEncode({
      'kind': 'maintenance',
      'uid': 'test',
      'vehicleId': 'bmw',
    });
    expect(
      notificationPath(payload, 'test', {'bmw'}),
      '/vehicles/bmw/maintenance?latest=1',
    );
    expect(notificationPath(payload, 'other', {'bmw'}), isNull);
    expect(notificationPath(payload, 'test', {'clio'}), isNull);
    expect(
      notificationPath('bmw', 'test', {'bmw'}),
      '/vehicles/bmw/inspection',
    );
  });
  testWidgets('Tap notification opens latest changed parts directly', (
    tester,
  ) async {
    final repository = FakeMaintenance();
    repository.records['bmw'] = [
      entry,
      MaintenanceEntry(
        id: 'old',
        date: DateTime(2025),
        odometerKm: 90000,
        items: ['battery'],
      ),
    ];
    addTearDown(repository.changes.close);
    final common = ReminderManager(TestGateway(), MemoryReminderStore());
    await tester.pumpWidget(
      authenticatedApp(maintenance: repository, reminders: common),
    );
    await tester.pumpAndSettle();
    common.handleNotificationTap(
      jsonEncode({'kind': 'maintenance', 'uid': 'test', 'vehicleId': 'bmw'}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Son bakım detayları'), findsOneWidget);
    expect(find.text('Motor yağı'), findsOneWidget);
    expect(find.text('Yağ filtresi'), findsOneWidget);
    expect(find.text('Akü'), findsNothing);
    expect(find.text('Tüm bakım geçmişi'), findsOneWidget);
  });
}
