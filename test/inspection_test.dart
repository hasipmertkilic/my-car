import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/app/app.dart';
import 'package:my_car/features/auth/controllers/auth_controller.dart';
import 'package:my_car/features/auth/models/app_user.dart';
import 'package:my_car/features/vehicles/controllers/vehicle_controller.dart';
import 'package:my_car/features/records/controllers/activity_controller.dart';
import 'package:my_car/features/inspection/models/inspection_schedule.dart';
import 'package:my_car/features/inspection/repositories/inspection_repository.dart';
import 'package:my_car/features/inspection/services/reminder_manager.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_vehicle_repository.dart';
import 'support/fake_activity_repository.dart';
import 'support/fake_inspection_repository.dart';

class TestGateway implements ReminderGateway {
  TestGateway({this.native = true});
  final bool native;
  bool permission = true;
  final List<ReminderPlan> scheduled = [];
  final List<int> shown = [], canceled = [];
  @override
  bool get supported => true;
  @override
  bool get canSchedule => native;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> refreshTimezone() async {}
  @override
  Future<void> cancel(int id) async {
    canceled.add(id);
  }

  @override
  Future<void> show(int id, String title, String body, String payload) async {
    shown.add(id);
  }

  @override
  Future<void> schedule(
    int id,
    DateTime date,
    String title,
    String body,
    String payload,
  ) async {
    scheduled.add(ReminderPlan(payload, '$id', date, title, body));
  }
}

void main() {
  test('Takvim yılı, artık yıl ve kalan gün hesabı', () {
    final leap = InspectionSchedule(
      lastDate: DateTime(2024, 2, 29),
      intervalYears: 1,
    );
    expect(leap.nextDate, DateTime(2025, 2, 28));
    expect(
      InspectionSchedule(
        lastDate: DateTime(2024, 2, 29),
        intervalYears: 4,
      ).nextDate,
      DateTime(2028, 2, 29),
    );
    final schedule = InspectionSchedule(
      lastDate: DateTime(2024, 10, 13),
      intervalYears: 2,
    );
    expect(schedule.daysUntil(DateTime(2026, 10, 12, 23, 59)), 1);
    expect(schedule.status(DateTime(2026, 10, 13, 10)), 'Muayene tarihi bugün');
    expect(schedule.status(DateTime(2026, 10, 15)), 'Muayene 2 gün gecikti');
    expect(
      InspectionSchedule.fromMap(schedule.toMap()).nextDate,
      schedule.nextDate,
    );
  });
  test('30/7/0 gün planları ve geçmişte kalan eşikler', () {
    final reminder = InspectionReminder(
      'car',
      'BMW',
      InspectionSchedule(lastDate: DateTime(2024, 11, 13), intervalYears: 2),
    );
    final plans = inspectionPlans(
      [reminder],
      DateTime(2026, 10, 1),
      scheduled: true,
    );
    expect(plans.map((p) => p.stage), ['30', '7', '0']);
    expect(plans.first.date, DateTime(2026, 10, 14, 9));
    final near = inspectionPlans(
      [reminder],
      DateTime(2026, 11, 10, 12),
      scheduled: true,
    );
    expect(near.where((p) => p.date == null).single.stage, '7');
    expect(near.where((p) => p.date != null).single.stage, '0');
    expect(
      inspectionPlans(
        [reminder],
        DateTime(2026, 11, 13, 8),
        scheduled: true,
      ).single.date,
      DateTime(2026, 11, 13, 9),
    );
  });
  test('İzin, yinelenen uyarı, tarih değişimi, çıkış ve kapatma', () async {
    final gateway = TestGateway();
    final store = MemoryReminderStore();
    final manager = ReminderManager(
      gateway,
      store,
      clock: () => DateTime(2026, 10, 13, 12),
    );
    final schedule = InspectionReminder(
      'car',
      'BMW',
      InspectionSchedule(lastDate: DateTime(2024, 11, 1), intervalYears: 2),
    );
    manager.synchronize('alice', [schedule]);
    await manager.settled;
    gateway.permission = false;
    expect(await manager.setEnabled(true), false);
    expect(manager.enabled, false);
    gateway.permission = true;
    expect(await manager.setEnabled(true), true);
    expect(gateway.shown, hasLength(1));
    expect(gateway.scheduled, hasLength(2));
    manager.synchronize('alice', [schedule]);
    await manager.settled;
    expect(gateway.shown, hasLength(1));
    manager.synchronize('alice', [
      InspectionReminder(
        'car',
        'BMW',
        InspectionSchedule(lastDate: DateTime(2026, 10, 13), intervalYears: 2),
      ),
    ]);
    await manager.settled;
    expect(gateway.canceled, isNotEmpty);
    expect(gateway.scheduled.last.date!.year, 2028);
    await manager.setEnabled(false);
    expect(store.list('inspection_managed'), isEmpty);
    await manager.setEnabled(true);
    manager.synchronize(null, []);
    await manager.settled;
    expect(store.list('inspection_managed'), isEmpty);
    expect(manager.owner, isNull);
    manager.synchronize('bob', [schedule]);
    await manager.settled;
    expect(manager.enabled, false);
  });
  test('Web açıkken uyarır; kapalı sayfa için plan oluşturmaz', () async {
    final gateway = TestGateway(native: false);
    final manager = ReminderManager(
      gateway,
      MemoryReminderStore(),
      clock: () => DateTime(2026, 10, 13, 12),
    );
    manager.synchronize('alice', [
      InspectionReminder(
        'car',
        'BMW',
        InspectionSchedule(lastDate: DateTime(2024, 10, 12), intervalYears: 2),
      ),
    ]);
    await manager.settled;
    await manager.setEnabled(true);
    expect(gateway.shown, hasLength(1));
    expect(gateway.scheduled, isEmpty);
  });
  testWidgets(
    'Muayene kaydı güncellenir ve ana ekranda yaklaşan tarih görünür',
    (tester) async {
      final inspections = FakeInspectionRepository();
      inspections.data['bmw'] = InspectionSchedule(
        lastDate: DateTime(2024, 10, 20),
        intervalYears: 2,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(
                user: const AppUser(uid: 'test', email: 'test@example.com'),
              ),
            ),
            vehicleRepositoryProvider.overrideWithValue(
              FakeVehicleRepository(seed: testVehicles),
            ),
            activityRepositoryProvider.overrideWithValue(
              FakeActivityRepository(),
            ),
            inspectionRepositoryProvider.overrideWithValue(inspections),
            inspectionClockProvider.overrideWithValue(DateTime(2026, 10, 13)),
          ],
          child: const MyCarApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Muayeneye 7 gün kaldı'), findsOneWidget);
      await tester.ensureVisible(find.text('Muayeneye 7 gün kaldı'));
      await tester.tap(find.text('Muayeneye 7 gün kaldı'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('2 yıl sonra'));
      await tester.tap(find.text('2 yıl sonra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 yıl sonra').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Muayeneyi kaydet'));
      await tester.tap(find.text('Muayeneyi kaydet'));
      await tester.pumpAndSettle();
      expect(inspections.data['bmw']!.intervalYears, 3);
      expect(find.text('Muayeneye 7 gün kaldı'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
