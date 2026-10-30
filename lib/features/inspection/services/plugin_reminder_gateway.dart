import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;
import 'reminder_manager.dart';

class PluginReminderGateway implements ReminderGateway {
  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;
  void Function(String?)? onTap;
  String? initialPayload;
  @override
  bool get supported => initialized;
  @override
  bool get canSchedule =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> initialize() async {
    if (!kIsWeb && !canSchedule) return;
    timezone_data.initializeTimeZones();
    await refreshTimezone();
    initialized =
        await plugin.initialize(
          onDidReceiveNotificationResponse: (response) {
            if (onTap != null) {
              onTap!(response.payload);
            } else {
              initialPayload = response.payload;
            }
          },
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_car'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
            web: WebInitializationSettings(),
          ),
        ) ??
        false;
    if (initialized && !kIsWeb) {
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        initialPayload = launch?.notificationResponse?.payload;
      }
    }
  }

  @override
  Future<void> refreshTimezone() async {
    if (!kIsWeb) {
      tz.setLocalLocation(
        tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                WebFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'inspection_reminders',
      'Muayene hatırlatmaları',
      channelDescription: 'Yaklaşan araç muayeneleri',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    web: WebNotificationDetails(lang: 'tr'),
  );
  static const maintenanceDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'maintenance_reminders',
      'Bakım hatırlatmaları',
      channelDescription:
          'Bakım kilometresine 2.000 km kala araç bakım hatırlatması',
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
    ),
    iOS: DarwinNotificationDetails(),
    web: WebNotificationDetails(lang: 'tr'),
  );
  @override
  Future<void> cancel(int id) async {
    if (initialized) await plugin.cancel(id: id);
  }

  @override
  Future<void> show(int id, String title, String body, String payload) =>
      plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: payload.startsWith('{"kind":"maintenance",')
            ? maintenanceDetails
            : details,
        payload: payload,
      );
  @override
  Future<void> schedule(
    int id,
    DateTime date,
    String title,
    String body,
    String payload,
  ) => plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime(tz.local, date.year, date.month, date.day, 9),
    notificationDetails: details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: payload,
  );
}

Future<ReminderManager> createReminderManager() async {
  try {
    final store = PreferenceReminderStore(
      await SharedPreferences.getInstance(),
    );
    final gateway = PluginReminderGateway();
    try {
      await gateway.initialize();
    } catch (_) {
      /* Ana ekran takibi bildirim izninden bağımsızdır. */
    }
    final manager = ReminderManager(gateway, store);
    gateway.onTap = manager.handleNotificationTap;
    manager.handleNotificationTap(gateway.initialPayload);
    return manager;
  } catch (_) {
    return ReminderManager(UnavailableReminderGateway(), MemoryReminderStore());
  }
}
