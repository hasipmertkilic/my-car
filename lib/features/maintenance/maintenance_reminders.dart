import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/formatters.dart';
import '../inspection/services/reminder_manager.dart';
import 'maintenance_entry.dart';

class MaintenanceReminder {
  const MaintenanceReminder(
    this.vehicleId,
    this.vehicleName,
    this.currentKm,
    this.entry,
  );
  final String vehicleId, vehicleName;
  final int currentKm;
  final MaintenanceEntry entry;
  String get cycle =>
      '${entry.id}/${entry.date.toIso8601String()}/${entry.odometerKm}/${entry.intervalKm}';
  String? get stage => entry.nextKm - currentKm > 2000
      ? null
      : currentKm > entry.nextKm
      ? 'late'
      : currentKm == entry.nextKm
      ? 'due'
      : 'near';
  String get title =>
      '${Formatters.number(entry.intervalKm)} km bakımınız ${stage == 'late'
          ? 'gecikti'
          : stage == 'due'
          ? 'geldi'
          : 'yaklaşıyor'}';
  String get body =>
      '$vehicleName • ${Formatters.number(entry.nextKm)} km bakım hedefi. Son bakımda değişen parçaları görmek için dokun.';
}

class MaintenanceReminderManager extends ChangeNotifier {
  MaintenanceReminderManager(this.gateway, this.store);
  final ReminderGateway gateway;
  final ReminderStore store;
  String? owner, error, _signature;
  bool busy = false, _disposed = false;
  int _generation = 0;
  List<MaintenanceReminder> _reminders = [];
  Future<void> _queue = Future.value();
  Future<void> get settled => _queue;
  bool get enabled => owner != null && store.flag('maintenance_enabled_$owner');
  void synchronize(String? uid, List<MaintenanceReminder> reminders) {
    if (_disposed) return;
    _reminders = reminders;
    final signature =
        '$uid/${uid != null && store.flag('maintenance_enabled_$uid')}/${reminders.map((r) => '${r.vehicleId}/${r.vehicleName}/${r.currentKm}/${r.cycle}').join('|')}';
    final changedOwner = owner != uid;
    owner = uid;
    if (changedOwner) notifyListeners();
    if (signature == _signature) return;
    _signature = signature;
    final generation = ++_generation;
    _queue = _queue.then((_) async {
      if (_disposed || generation != _generation) return;
      try {
        await _apply(uid, reminders, generation);
        error = null;
      } catch (_) {
        error =
            'Bakım bildirimi gösterilemedi. Ana ekrandaki bakım uyarısını kontrol edebilirsin.';
      }
      if (!_disposed) notifyListeners();
    });
  }

  Future<bool> setEnabled(bool value) async {
    final uid = owner;
    if (uid == null || busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (value && (!gateway.supported || !await gateway.requestPermission())) {
        error =
            'Bildirim izni verilmedi. Cihaz veya tarayıcı ayarlarından bildirim iznini aç.';
        return false;
      }
      if (_disposed || owner != uid) return false;
      await store.setFlag('maintenance_enabled_$uid', value);
      _signature = null;
      synchronize(uid, _reminders);
      await settled;
      return error == null;
    } catch (_) {
      error = 'Bildirim tercihi değiştirilemedi. Tekrar dene.';
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _apply(
    String? uid,
    List<MaintenanceReminder> reminders,
    int generation,
  ) async {
    final wanted = <String>[];
    if (uid != null && enabled && gateway.supported) {
      for (final reminder in reminders) {
        if (_disposed || generation != _generation) return;
        final stage = reminder.stage;
        if (stage == null) continue;
        final key = '$uid/${reminder.vehicleId}';
        var id = store.number('maintenance_id_$key');
        if (id == null) {
          id = store.number('maintenance_next_id') ?? 1000000000;
          await store.setNumber('maintenance_id_$key', id);
          await store.setNumber('maintenance_next_id', id + 1);
        }
        final sentKey = 'maintenance_sent_$key/${reminder.cycle}/$stage';
        if (!store.flag(sentKey)) {
          await store.setList(
            'maintenance_managed',
            {...store.list('maintenance_managed'), '$id'}.toList(),
          );
          if (_disposed || generation != _generation) return;
          await gateway.show(
            id,
            reminder.title,
            reminder.body,
            jsonEncode({
              'kind': 'maintenance',
              'uid': uid,
              'vehicleId': reminder.vehicleId,
            }),
          );
          await store.setFlag(sentKey, true);
        }
        wanted.add('$id');
      }
    }
    if (_disposed || generation != _generation) return;
    for (final old in store.list('maintenance_managed')) {
      if (!wanted.contains(old)) await gateway.cancel(int.parse(old));
    }
    await store.setList('maintenance_managed', wanted);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

final maintenanceReminderManagerProvider = Provider<MaintenanceReminderManager>(
  (ref) {
    final common = ref.watch(reminderManagerProvider);
    final manager = MaintenanceReminderManager(common.gateway, common.store);
    ref.onDispose(manager.dispose);
    return manager;
  },
);
