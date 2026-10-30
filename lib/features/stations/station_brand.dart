import 'package:flutter/material.dart';

const _brandPatterns = {
  'shell': r'\bshell\b',
  'opet': r'\bopet\b',
  'petrol_ofisi': r'\bpetrol\s*ofisi\b',
  'bp': r'\bbp\b',
  'totalenergies': r'\btotal(?:\s*energies)?\b',
};

String? stationBrandAsset(String name) {
  final normalized = name
      .replaceAll('İ', 'i')
      .replaceAll('ı', 'i')
      .toLowerCase();
  final matches = _brandPatterns.entries
      .where((entry) => RegExp(entry.value).hasMatch(normalized))
      .toList();
  // A dealer name containing multiple brands is ambiguous: keep the pump icon.
  return matches.length == 1
      ? 'assets/station_brands/${matches.single.key}.png'
      : null;
}

class StationBrandBadge extends StatelessWidget {
  const StationBrandBadge({super.key, required this.name, this.size = 34});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final asset = stationBrandAsset(name);
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size + 16,
      height: size + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: asset == null
            ? colors.primary.withValues(alpha: .14)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: asset == null
          ? Icon(
              Icons.local_gas_station_rounded,
              color: colors.primary,
              size: size,
            )
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => Icon(
                Icons.local_gas_station_rounded,
                color: colors.primary,
                size: size,
              ),
            ),
    );
  }
}
