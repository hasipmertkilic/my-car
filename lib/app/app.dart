import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/controllers/theme_controller.dart';
import 'router.dart';
import 'theme.dart';
import '../features/inspection/widgets/inspection_reminder_host.dart';
import '../features/maintenance/maintenance_reminder_host.dart';
import '../core/widgets/notification_open_host.dart';

class MyCarApp extends ConsumerWidget {
  const MyCarApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => InspectionReminderHost(
    child: MaintenanceReminderHost(
      child: NotificationOpenHost(
        child: MaterialApp.router(
          title: 'My Car',
          debugShowCheckedModeBanner: false,
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.build(Brightness.light),
          darkTheme: AppTheme.build(Brightness.dark),
          themeMode: ref.watch(themeModeProvider),
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
}
