import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/maintenance/maintenance_entry.dart';
import 'package:my_car/features/maintenance/maintenance_repository.dart';
import 'widget_test.dart' show authenticatedApp;

class FakeMaintenance implements MaintenanceRepository {
  final records = <String, List<MaintenanceEntry>>{};
  final changes = StreamController<void>.broadcast(sync: true);
  String? failure;
  @override
  Stream<List<MaintenanceEntry>> watch(String id) => Stream.multi((controller) {
    controller.add(sortMaintenance(records[id] ?? []));
    final subscription = changes.stream.listen(
      (_) => controller.add(sortMaintenance(records[id] ?? [])),
    );
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> save(String id, MaintenanceEntry entry) async {
    if (failure != null) throw MaintenanceFailure(failure!);
    final list = records.putIfAbsent(id, () => []);
    final entryId = entry.id.isEmpty ? 'entry-${list.length}' : entry.id;
    list.removeWhere((old) => old.id == entryId);
    list.add(MaintenanceEntry.fromMap(entryId, entry.toMap()));
    changes.add(null);
  }
}

void main() {
  test(
    'Bakım uyarısı yalnızca kilometreye bağlıdır; eski tarih uyarı oluşturmaz',
    () {
      final entry = MaintenanceEntry(
        date: DateTime(2020, 1, 1),
        odometerKm: 100000,
        items: ['engine_oil'],
      );
      expect(entry.nextKm, 110000);
      expect(entry.approaching(107999), isFalse);
      expect(entry.overdue(100000), isFalse);
      expect(entry.status(100000), 'Bakım planın güncel');
      expect(entry.approaching(108000), isTrue);
      expect(entry.status(110000), 'Periyodik bakım zamanı geldi');
      expect(entry.overdue(110001), isTrue);
      final restored = MaintenanceEntry.fromMap('legacy', {
        ...entry.toMap(),
        'intervalMonths': 12,
      });
      expect(restored.nextKm, 110000);
      expect(restored.status(100000), 'Bakım planın güncel');
      expect(restored.toMap().containsKey('intervalMonths'), isFalse);
    },
  );
  test('Backfilled history, amount and changed parts survive round trip', () {
    final recent = MaintenanceEntry(
      id: 'new',
      date: DateTime(2026, 10, 1),
      odometerKm: 120000,
      items: ['engine_oil', 'oil_filter'],
      amountKurus: 275050,
      details: '0W-30 yağ',
      service: 'Servis',
      notes: 'Kontrol',
    );
    final old = MaintenanceEntry(
      id: 'old',
      date: DateTime(2025, 1, 1),
      odometerKm: 100000,
      items: ['battery'],
    );
    final restored = MaintenanceEntry.fromMap(recent.id, recent.toMap());
    expect(restored.items, ['engine_oil', 'oil_filter']);
    expect(restored.amountKurus, 275050);
    expect(restored.details, '0W-30 yağ');
    expect(sortMaintenance([old, restored]).first.id, 'new');
    expect(restored.valid(DateTime(2026, 10, 23)), isTrue);
    expect(
      MaintenanceEntry(
        date: DateTime(2026),
        odometerKm: 0,
      ).valid(DateTime(2026, 10)),
      isFalse,
    );
    expect(
      MaintenanceEntry(
        date: DateTime(2026),
        odometerKm: 0,
        items: ['unknown'],
      ).valid(DateTime(2026, 10)),
      isFalse,
    );
  });
  testWidgets(
    'Bakım parçaları kaydedilir, eski geçmiş korunur ve kayıt düzenlenir',
    (tester) async {
      final repository = FakeMaintenance();
      final old = MaintenanceEntry(
        id: 'old',
        date: DateTime.now().subtract(const Duration(days: 400)),
        odometerKm: 100000,
        items: ['battery'],
        details: 'Eski akü kaydı',
      );
      repository.records['bmw'] = [old];
      addTearDown(repository.changes.close);
      await tester.pumpWidget(authenticatedApp(maintenance: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hızlı erişimi aç'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bakım takibi'));
      await tester.tap(find.text('Bakım takibi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bakım kaydı ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bakım kilometresi'),
        '125000',
      );
      await tester.ensureVisible(find.text('Motor yağı'));
      await tester.tap(find.text('Motor yağı'));
      await tester.tap(find.text('Yağ filtresi'));
      await tester.ensureVisible(
        find.widgetWithText(
          TextFormField,
          'Diğer işlemler / parça ayrıntıları',
        ),
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Diğer işlemler / parça ayrıntıları',
        ),
        '0W-30 yağ kullanıldı',
      );
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Bakım aralığı (km)'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bakım aralığı (km)'),
        '1000',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bakımı kaydet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bakımı kaydet'));
      await tester.pumpAndSettle();
      expect(repository.records['bmw']!.length, 2);
      final latest = sortMaintenance(repository.records['bmw']!).first;
      expect(latest.items, ['engine_oil', 'oil_filter']);
      expect(latest.details, '0W-30 yağ kullanıldı');
      expect(repository.records['bmw']!.first.details, 'Eski akü kaydı');
      await tester.ensureVisible(find.text('Kaydı düzenle').first);
      await tester.tap(find.text('Kaydı düzenle').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(
          TextFormField,
          'Diğer işlemler / parça ayrıntıları',
        ),
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Diğer işlemler / parça ayrıntıları',
        ),
        'Fren kontrolü de yapıldı',
      );
      repository.failure = 'Bağlantı kesildi.';
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bakımı kaydet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bakımı kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Bağlantı kesildi.'), findsOneWidget);
      expect(
        sortMaintenance(repository.records['bmw']!).first.details,
        '0W-30 yağ kullanıldı',
      );
      repository.failure = null;
      await tester.tap(find.text('Bakımı kaydet'));
      await tester.pumpAndSettle();
      expect(repository.records['bmw']!.length, 2);
      expect(
        sortMaintenance(repository.records['bmw']!).first.details,
        'Fren kontrolü de yapıldı',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Periyodik bakım yaklaşıyor'), findsOneWidget);
      await tester.tap(find.byTooltip('Araç seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renault Clio'));
      await tester.pumpAndSettle();
      expect(find.text('Periyodik bakım yaklaşıyor'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
