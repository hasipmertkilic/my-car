import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/inspection/services/reminder_manager.dart';
import '../../features/vehicles/controllers/vehicle_controller.dart';

String? notificationPath(String payload, String uid, Set<String> vehicleIds) {
  try {
    final data = jsonDecode(payload) as Map;
    final id = data['vehicleId'];
    if (data['uid'] != uid || id is! String || !vehicleIds.contains(id)) {
      return null;
    }
    if (data['kind'] == 'maintenance') {
      return Uri(
        pathSegments: ['', 'vehicles', id, 'maintenance'],
        queryParameters: {'latest': '1'},
      ).toString();
    }
  } catch (_) {
    // Existing inspection notifications carried only the vehicle ID.
    if (vehicleIds.contains(payload)) {
      return Uri(
        pathSegments: ['', 'vehicles', payload, 'inspection'],
      ).toString();
    }
  }
  return null;
}

class NotificationOpenHost extends ConsumerWidget {
  const NotificationOpenHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final manager = ref.watch(reminderManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted ||
              session.loading ||
              session.user == null ||
              vehicles.isLoading ||
              vehicles.hasError) {
            return;
          }
          final payload = manager.takeNotificationPayload();
          if (payload == null) return;
          final path = notificationPath(
            payload,
            session.user!.uid,
            vehicles.requireValue.map((v) => v.id).toSet(),
          );
          if (path != null) ref.read(routerProvider).push(path);
        });
        return child;
      },
    );
  }
}
