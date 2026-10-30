import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inspection_schedule.dart';

abstract interface class ReminderStore {
  bool flag(String key);
  int? number(String key);
  List<String> list(String key);
  Future<void> setFlag(String key, bool value);
  Future<void> setNumber(String key, int value);
  Future<void> setList(String key, List<String> value);
}

class MemoryReminderStore implements ReminderStore {
  final Map<String, Object> values = {};
  @override
  bool flag(String key) => values[key] == true;
  @override
  int? number(String key) => values[key] as int?;
  @override
  List<String> list(String key) => values[key] as List<String>? ?? [];
  @override
  Future<void> setFlag(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setNumber(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setList(String key, List<String> value) async {
    values[key] = value;
  }
}

class PreferenceReminderStore implements ReminderStore {
  PreferenceReminderStore(this.preferences);
  final SharedPreferences preferences;
  @override
  bool flag(String key) => preferences.getBool(key) ?? false;
  @override
  int? number(String key) => preferences.getInt(key);
  @override
  List<String> list(String key) => preferences.getStringList(key) ?? [];
  @override
  Future<void> setFlag(String key, bool value) async {
    await preferences.setBool(key, value);
  }

  @override
  Future<void> setNumber(String key, int value) async {
    await preferences.setInt(key, value);
  }

  @override
  Future<void> setList(String key, List<String> value) async {
    await preferences.setStringList(key, value);
  }
}

abstract interface class ReminderGateway {
  bool get supported;
  bool get canSchedule;
  Future<bool> requestPermission();
  Future<void> refreshTimezone();
  Future<void> cancel(int id);
  Future<void> show(int id, String title, String body, String payload);
  Future<void> schedule(
    int id,
    DateTime date,
    String title,
    String body,
    String payload,
  );
}

class UnavailableReminderGateway implements ReminderGateway {
  @override
  bool get supported => false;
  @override
  bool get canSchedule => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> refreshTimezone() async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> show(int id, String title, String body, String payload) async {}
  @override
  Future<void> schedule(
    int id,
    DateTime date,
    String title,
    String body,
    String payload,
  ) async {}
}

class ReminderPlan {
  const ReminderPlan(
    this.vehicleId,
    this.stage,
    this.date,
    this.title,
    this.body,
  );
  final String vehicleId, stage, title, body;
  final DateTime? date;
}

List<ReminderPlan> inspectionPlans(
  List<InspectionReminder> reminders,
  DateTime now, {
  required bool scheduled,
}) {
  final plans = <ReminderPlan>[];
  for (final reminder in reminders) {
    final due = reminder.schedule.nextDate;
    final days = reminder.schedule.daysUntil(now);
    final title = '${reminder.vehicleName} • Muayene';
    if (scheduled) {
      for (final offset in [30, 7, 0]) {
        final calendar = DateTime.utc(
          due.year,
          due.month,
          due.day,
        ).subtract(Duration(days: offset));
        final date = DateTime(calendar.year, calendar.month, calendar.day, 9);
        if (date.isAfter(now)) {
          plans.add(
            ReminderPlan(
              reminder.vehicleId,
              '$offset',
              date,
              title,
              offset == 0
                  ? 'Muayene tarihin bugün.'
                  : 'Muayenene $offset gün kaldı.',
            ),
          );
        }
      }
    }
    final stage = days < 0
        ? 'late'
        : days == 0
        ? '0'
        : days <= 7
        ? '7'
        : days <= 30
        ? '30'
        : null;
    final exactFuture =
        scheduled &&
        stage != null &&
        stage != 'late' &&
        days == int.parse(stage) &&
        DateTime(now.year, now.month, now.day, 9).isAfter(now);
    if (stage != null && !exactFuture) {
      plans.add(
        ReminderPlan(
          reminder.vehicleId,
          stage,
          null,
          title,
          reminder.schedule.status(now),
        ),
      );
    }
  }
  final immediate = plans.where((p) => p.date == null).toList();
  final future = plans.where((p) => p.date != null).toList()
    ..sort((a, b) => a.date!.compareTo(b.date!));
  // iOS en fazla 64 planı tutar. En yakın 60 planı kullan.
  return [...immediate, ...future.take(60)];
}

class ReminderManager extends ChangeNotifier {
  ReminderManager(this.gateway, this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    owner = store.list('inspection_active_owner').firstOrNull;
  }
  final ReminderGateway gateway;
  final ReminderStore store;
  final DateTime Function() clock;
  String? owner;
  String? error;
  bool busy = false;
  bool get enabled => owner != null && store.flag('inspection_enabled_$owner');
  Future<void> _queue = Future.value();
  String? _signature;
  int _generation = 0;
  List<InspectionReminder> _reminders = [];
  String? _notificationPayload;
  void handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    _notificationPayload = payload;
    notifyListeners();
  }

  String? takeNotificationPayload() {
    final payload = _notificationPayload;
    _notificationPayload = null;
    return payload;
  }

  Future<void> get settled => _queue;
  void attachOwner(String uid) {
    if (owner == uid) return;
    owner = uid;
    notifyListeners();
  }

  void synchronize(String? uid, List<InspectionReminder> reminders) {
    final now = clock();
    final signature =
        '$uid|${uid == null ? false : store.flag('inspection_enabled_$uid')}|${now.year}-${now.month}-${now.day}|${now.timeZoneOffset.inMinutes}|${reminders.map((r) => '${r.vehicleId}:${r.vehicleName}:${r.schedule.nextDate.toIso8601String()}').join('|')}';
    _reminders = reminders;
    if (_signature == signature) return;
    _signature = signature;
    owner = uid;
    final generation = ++_generation;
    _queue = _queue.then((_) async {
      if (generation != _generation) return;
      try {
        await _apply(uid, reminders, generation);
        error = null;
      } catch (_) {
        error =
            'Bildirimler hazırlanamadı. Muayene bilgisi ana ekranda görünmeye devam eder. Tekrar açmayı deneyebilirsin.';
      }
      notifyListeners();
    });
  }

  Future<bool> setEnabled(bool value) async {
    final uid = owner;
    if (uid == null || busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (value && (!gateway.supported || !await gateway.requestPermission())) {
        error =
            'Bildirim izni verilmedi veya bu ortam bildirimleri desteklemiyor. İzni cihaz/tarayıcı ayarlarından kontrol et.';
        return false;
      }
      if (owner != uid) return false;
      await store.setFlag('inspection_enabled_$uid', value);
      _signature = null;
      synchronize(uid, _reminders);
      await settled;
      return error == null;
    } catch (_) {
      error = 'Bildirim tercihi değiştirilemedi. Tekrar dene.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _apply(
    String? uid,
    List<InspectionReminder> reminders,
    int generation,
  ) async {
    for (final id in store.list('inspection_managed')) {
      await gateway.cancel(int.parse(id));
    }
    await store.setList('inspection_managed', []);
    await store.setList('inspection_active_owner', uid == null ? [] : [uid]);
    if (generation != _generation ||
        uid == null ||
        !enabled ||
        !gateway.supported) {
      return;
    }
    await gateway.refreshTimezone();
    final plans = inspectionPlans(
      reminders,
      clock(),
      scheduled: gateway.canSchedule,
    );
    final managed = <String>[];
    for (final plan in plans) {
      if (generation != _generation) return;
      final reminder = reminders.firstWhere(
        (r) => r.vehicleId == plan.vehicleId,
      );
      final prefix =
          '$uid/${plan.vehicleId}/${reminder.schedule.nextDate.toIso8601String()}';
      final sentKey = 'inspection_sent_$prefix/${plan.stage}';
      var baseId = store.number('inspection_id_$uid/${plan.vehicleId}');
      if (baseId == null) {
        baseId = max(1, store.number('inspection_next_id') ?? 1);
        await store.setNumber('inspection_id_$uid/${plan.vehicleId}', baseId);
        await store.setNumber('inspection_next_id', baseId + 4);
      }
      final id =
          baseId +
          switch (plan.stage) {
            '30' => 0,
            '7' => 1,
            '0' => 2,
            _ => 3,
          };
      if (plan.date == null) {
        if (store.flag(sentKey)) continue;
        await gateway.show(id, plan.title, plan.body, plan.vehicleId);
      } else {
        await gateway.schedule(
          id,
          plan.date!,
          plan.title,
          plan.body,
          plan.vehicleId,
        );
      }
      managed.add('$id');
      await store.setList('inspection_managed', [...managed]);
      await store.setFlag(sentKey, true);
    }
  }
}

final reminderManagerProvider = Provider<ReminderManager>((ref) {
  final manager = ReminderManager(
    UnavailableReminderGateway(),
    MemoryReminderStore(),
  );
  return manager;
});
