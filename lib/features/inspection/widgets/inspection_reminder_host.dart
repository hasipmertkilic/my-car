import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../models/inspection_schedule.dart';
import '../repositories/inspection_repository.dart';
import '../services/reminder_manager.dart';

class InspectionReminderHost extends ConsumerStatefulWidget {
  const InspectionReminderHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<InspectionReminderHost> createState() =>
      _InspectionReminderHostState();
}

class _InspectionReminderHostState extends ConsumerState<InspectionReminderHost>
    with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        ref.invalidate(inspectionClockProvider);
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(inspectionClockProvider);
      setState(() {});
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(signedInUserProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final manager = ref.watch(reminderManagerProvider);
    final uid = user.asData?.value?.uid;
    final reminders = <InspectionReminder>[];
    var ready = !vehicles.isLoading && !vehicles.hasError;
    for (final vehicle in vehicles.asData?.value ?? []) {
      final inspection = ref.watch(inspectionProvider(vehicle.id));
      if (inspection.isLoading || inspection.hasError) ready = false;
      final schedule = inspection.asData?.value;
      if (schedule != null) {
        reminders.add(InspectionReminder(vehicle.id, vehicle.name, schedule));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (user.isLoading || user.hasError) return;
      if (uid == null || ready) {
        manager.synchronize(uid, reminders);
      } else if (manager.owner == null) {
        manager.attachOwner(uid);
      } else if (manager.owner != uid) {
        manager.synchronize(uid, []);
      }
    });
    return widget.child;
  }
}
