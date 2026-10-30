import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/status_colors.dart';
import '../../inspection/repositories/inspection_repository.dart';
import '../../insurance/models/insurance_policy.dart';
import '../../insurance/repositories/policy_repository.dart';
import '../../maintenance/maintenance_entry.dart';
import '../../maintenance/maintenance_repository.dart';
import '../../vehicles/controllers/vehicle_controller.dart';

/// Only upcoming/overdue reminders belong on the otherwise quiet home screen.
class DashboardAlerts extends ConsumerWidget {
  const DashboardAlerts({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(inspectionClockProvider);
    final inspection = ref.watch(inspectionProvider(vehicleId)).asData?.value;
    final policies = ref.watch(policiesProvider(vehicleId)).asData?.value ?? [];
    final maintenance = sortMaintenance(
      ref.watch(maintenanceProvider(vehicleId)).asData?.value ?? [],
    ).firstOrNull;
    final car = ref
        .watch(vehiclesProvider)
        .asData
        ?.value
        .where((v) => v.id == vehicleId)
        .firstOrNull;
    final alerts = <({String text, String path, RecordStatus status})>[
      if (maintenance != null &&
          car != null &&
          maintenance.approaching(car.currentKm))
        (
          text: maintenance.status(car.currentKm),
          path: '/vehicles/$vehicleId/maintenance?latest=1',
          status: maintenance.overdue(car.currentKm)
              ? RecordStatus.overdue
              : RecordStatus.attention,
        ),
      if (inspection != null && inspection.daysUntil(now) <= 30)
        (
          text: inspection.status(now),
          path: '/vehicles/$vehicleId/inspection',
          status: StatusColors.forDays(inspection.daysUntil(now)),
        ),
      for (final kind in ['traffic', 'casco'])
        if (relevantPolicy(policies, kind, now) case final policy?)
          if (policy.started(now) && policy.daysUntil(now) <= 30)
            (
              text: '${policy.title}: ${policy.status(now)}',
              path: '/vehicles/$vehicleId/policies',
              status: StatusColors.forDays(policy.daysUntil(now)),
            ),
    ];
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          for (final alert in alerts)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Icon(
                Icons.notifications_active_outlined,
                color: StatusColors.foreground(context, alert.status),
              ),
              title: Text(alert.text),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(alert.path),
            ),
        ],
      ),
    );
  }
}
