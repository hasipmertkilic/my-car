import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/metric_card.dart';
import '../utils/record_calculations.dart';

class SummaryMetrics extends StatelessWidget {
  const SummaryMetrics({super.key, required this.summary});
  final RecordSummary summary;
  @override
  Widget build(BuildContext context) => MetricGrid(
    children: [
      MetricCard(
        icon: Icons.payments_outlined,
        label: 'Bu ayki gider',
        value: Formatters.preciseMoney(summary.monthlyKurus / 100),
        detail: 'Yakıt ve tüm masraflar',
      ),
      MetricCard(
        icon: Icons.local_gas_station_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        label: 'Ortalama tüketim',
        value: summary.fuelMetrics.litersPer100Km == null
            ? 'Henüz yok'
            : '${Formatters.decimal(summary.fuelMetrics.litersPer100Km!)} L/100 km',
        detail: 'Son yakıt türünün dolu depo aralıkları',
      ),
    ],
  );
}
