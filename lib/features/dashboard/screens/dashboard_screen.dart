import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
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
      final scheme = Theme.of(context).colorScheme;
      return PageContent(
        children: [
          const SectionTitle(
            'Yola hazır mısın?',
            subtitle: 'Aracınla ilgili her şey, tek bir yerde.',
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.primary.withValues(alpha: .4)),
              gradient: LinearGradient(
                colors: [scheme.surfaceContainer, scheme.surface],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: scheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AKTİF ARACIN',
                        style: TextStyle(
                          color: scheme.primary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  vehicle.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${vehicle.plate} • ${vehicle.year}',
                  style: TextStyle(color: scheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  '${vehicle.fuelType} • ${vehicle.transmission} • ${vehicle.engineCc} cc',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${Formatters.number(vehicle.currentKm)} km',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DashboardAlerts(vehicleId: vehicle.id),
          const SizedBox(height: 24),
          const SectionTitle('Araç geçmişi'),
          const SizedBox(height: 16),
          ActivityScope(
            vehicleId: vehicle.id,
            builder: (records) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SummaryMetrics(summary: RecordSummary(records)),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const Text('Henüz işlem kaydı yok.')
                else
                  Text(
                    'Son işlem: ${records.first.title} • ${Formatters.date(records.first.date)} • ${Formatters.preciseMoney(records.first.amount)}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/records'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Tüm kayıtları gör'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/vehicles/${vehicle.id}/parking/history'),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Park yerlerim'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
