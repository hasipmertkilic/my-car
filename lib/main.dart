import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'features/inspection/services/plugin_reminder_gateway.dart';
import 'features/inspection/services/reminder_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final availability = await initializeFirebase();
  final reminders = await createReminderManager();
  runApp(
    ProviderScope(
      overrides: [
        firebaseAvailabilityProvider.overrideWithValue(availability),
        reminderManagerProvider.overrideWithValue(reminders),
      ],
      child: const MyCarApp(),
    ),
  );
}
