import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../../records/utils/record_calculations.dart';
import '../../records/widgets/activity_scope.dart';
import '../../records/widgets/summary_metrics.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context) => VehicleScope(
    builder: (vehicle) => ActivityScope(
      vehicleId: vehicle!.id,
      builder: (records) {
        final summary = RecordSummary(records);
        final categories = summary.categories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final now = DateTime.now();
        final months = List.generate(
          6,
          (i) => DateTime(now.year, now.month - 5 + i),
        );
        final amounts = months
            .map(
              (month) => records
                  .where(
                    (r) =>
                        r.date.year == month.year &&
                        r.date.month == month.month,
                  )
                  .fold<int>(0, (sum, r) => sum + r.amountKurus),
            )
            .toList();
        final largest = max(1, amounts.fold<int>(0, max));
        return PageContent(
          children: [
            SectionTitle('İstatistikler', subtitle: vehicle.name),
            SummaryMetrics(summary: summary),
            const SizedBox(height: 12),
            MetricGrid(
              children: [
                MetricCard(
                  icon: Icons.speed_outlined,
                  accent: Theme.of(context).colorScheme.secondary,
                  label: 'Güncel kilometre',
                  value: Formatters.number(vehicle.currentKm),
                  detail: 'Aracın kilometre sayacı',
                ),
                MetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Toplam gider',
                  value: Formatters.preciseMoney(summary.totalKurus / 100),
                  detail: 'Tüm kayıtlı dönemler',
                ),
                MetricCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'Bu yılki gider',
                  value: Formatters.preciseMoney(summary.annualKurus / 100),
                  detail: '${now.year} kayıtları',
                ),
                MetricCard(
                  icon: Icons.local_gas_station_outlined,
                  accent: Theme.of(context).colorScheme.secondary,
                  label: 'Toplam yakıt',
                  value: '${Formatters.number(summary.litersMilli / 1000)} L',
                  detail: Formatters.preciseMoney(summary.fuelKurus / 100),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (summary.fuelMetrics.distanceKm > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yakıt hesabı • ${Formatters.number(summary.fuelMetrics.distanceKm)} km',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${Formatters.decimal(summary.fuelMetrics.kmPerLiter!)} km/L',
                      ),
                      Text(
                        '100 km yakıt maliyeti: ${Formatters.preciseMoney(summary.fuelMetrics.costPer100Km!)}',
                      ),
                    ],
                  ),
                ),
              )
            else
              const Text(
                'Tüketim ve yakıt maliyeti hesabı için farklı kilometrelerde en az iki dolu depo kaydı gerekir. Kısmi dolumlar aradaki litre toplamına dahil edilir.',
              ),
            const SizedBox(height: 24),
            const SectionTitle('Son 6 ayın giderleri'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '6 ay toplamı',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                Formatters.preciseMoney(
                                  amounts.fold<int>(
                                        0,
                                        (sum, value) => sum + value,
                                      ) /
                                      100,
                                ),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 14),
                    for (var i = 0; i < months.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${months[i].month.toString().padLeft(2, '0')}/${months[i].year}',
                                  ),
                                ),
                                Text(Formatters.preciseMoney(amounts[i] / 100)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: amounts[i] / largest,
                              color: amounts[i] == largest
                                  ? Theme.of(context).colorScheme.secondary
                                  : Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .1),
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Kategori dağılımı'),
            if (categories.isEmpty)
              const Text('Gider kaydı eklendiğinde dağılım burada görünecek.'),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(category.key)),
                        Text(Formatters.preciseMoney(category.value / 100)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: category.value / max(1, summary.totalKurus),
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Kayıtlarla gözlenen mesafe: ${Formatters.number(summary.observedKm)} km. Bu değer aracın tüm kullanım geçmişini kapsamaz.',
            ),
          ],
        );
      },
    ),
  );
}
