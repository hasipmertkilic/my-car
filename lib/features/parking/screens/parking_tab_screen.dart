import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../widgets/parking_card.dart';

class ParkingTabScreen extends StatelessWidget {
  const ParkingTabScreen({super.key});
  @override
  Widget build(BuildContext context) => VehicleScope(
    builder: (vehicle) => PageContent(
      children: [
        SectionTitle(
          'Park yerim',
          subtitle: '${vehicle!.name} • ${vehicle.plate}',
        ),
        ParkingCard(key: ValueKey(vehicle.id), vehicleId: vehicle.id),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () =>
              context.push('/vehicles/${vehicle.id}/parking/history'),
          icon: const Icon(Icons.history),
          label: const Text('Park yerlerim'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.go('/garage'),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Başka araç seç'),
        ),
      ],
    ),
  );
}
