import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../vehicles/controllers/vehicle_controller.dart';
import 'maintenance_entry.dart';
import 'maintenance_repository.dart';
import 'maintenance_reminders.dart';

class MaintenanceReminderHost extends ConsumerStatefulWidget {
  const MaintenanceReminderHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<MaintenanceReminderHost> createState() =>
      _MaintenanceReminderHostState();
}

class _MaintenanceReminderHostState
    extends ConsumerState<MaintenanceReminderHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(signedInUserProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final manager = ref.watch(maintenanceReminderManagerProvider);
    final uid = user.asData?.value?.uid;
    final reminders = <MaintenanceReminder>[];
    var ready = !vehicles.isLoading && !vehicles.hasError;
    for (final car in vehicles.asData?.value ?? []) {
      final records = ref.watch(maintenanceProvider(car.id));
      if (records.isLoading || records.hasError) ready = false;
      final latest = sortMaintenance(records.asData?.value ?? []).firstOrNull;
      if (latest != null) {
        reminders.add(
          MaintenanceReminder(car.id, car.name, car.currentKm, latest),
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || user.isLoading || user.hasError) return;
      if (uid == null || ready) {
        manager.synchronize(uid, reminders);
      } else if (manager.owner != uid) {
        manager.synchronize(uid, []);
      }
    });
    return widget.child;
  }
}
