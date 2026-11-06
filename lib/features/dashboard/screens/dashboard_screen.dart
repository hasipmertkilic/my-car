import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../../vehicles/widgets/vehicle_overview_card.dart';
import '../../vehicles/widgets/vehicle_picker.dart';
import '../../records/widgets/activity_scope.dart';
import '../../records/widgets/summary_metrics.dart';
import '../../records/utils/record_calculations.dart';
import '../widgets/dashboard_alerts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => VehicleScope(
    builder: (selected) {
      final vehicle = selected!;
      final t = Theme.of(context);
      final c = t.colorScheme;
      return PageContent(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SÜRÜŞ PANELİ',
                  style: t.textTheme.labelSmall?.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Kontrol sende.', style: t.textTheme.headlineLarge),
              ],
            ),
          ),
          VehicleOverviewCard(
            vehicle: vehicle,
            onSelect: () => showVehiclePicker(context),
          ),
          DashboardAlerts(vehicleId: vehicle.id),
          const SizedBox(height: 28),
          ActivityScope(
            vehicleId: vehicle.id,
            builder: (records) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Bir bakışta', style: t.textTheme.titleLarge),
                    ),
                    Text(
                      'BU AY',
                      style: t.textTheme.labelSmall?.copyWith(
                        color: c.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SummaryMetrics(summary: RecordSummary(records)),
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text('Araç geçmişi', style: t.textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.go('/records'),
                      child: const Text('Tüm kayıtları gör'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (records.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          color: c.onSurfaceVariant,
                          size: 30,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Henüz işlem kaydı yok.',
                                style: t.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kayıtların burada bir zaman akışına dönüşecek.',
                                style: t.textTheme.bodySmall?.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < records.take(3).length; i++) ...[
                          if (i > 0)
                            Divider(
                              indent: 62,
                              endIndent: 18,
                              color: c.outlineVariant,
                            ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: records[i].isFuel
                                    ? c.secondaryContainer
                                    : c.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                records[i].isFuel
                                    ? Icons.local_gas_station_outlined
                                    : Icons.receipt_long_outlined,
                                size: 17,
                                color: records[i].isFuel
                                    ? c.secondary
                                    : c.primary,
                              ),
                            ),
                            title: Text(
                              records[i].title,
                              style: t.textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              Formatters.date(records[i].date),
                              style: t.textTheme.bodySmall,
                            ),
                            trailing: Text(
                              Formatters.preciseMoney(records[i].amount),
                              style: t.textTheme.labelLarge,
                            ),
                            onTap: () => context.go('/records'),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(Icons.route_outlined, color: c.primary),
              title: const Text('Park yerlerim'),
              subtitle: const Text('Önceki park noktalarına göz at'),
              trailing: const Icon(Icons.arrow_outward_rounded, size: 20),
              onTap: () =>
                  context.push('/vehicles/${vehicle.id}/parking/history'),
            ),
          ),
        ],
      );
    },
  );
}
