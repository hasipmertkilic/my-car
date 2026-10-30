import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/page_content.dart';
import '../controllers/vehicle_controller.dart';
import '../widgets/vehicle_scope.dart';
import 'vehicle_form_screen.dart';

class VehicleEditScreen extends ConsumerWidget {
  const VehicleEditScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => VehicleScope(
    allowEmpty: true,
    builder: (_) {
      final vehicle = ref
          .watch(vehiclesProvider)
          .asData!
          .value
          .where((v) => v.id == id)
          .firstOrNull;
      if (vehicle == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Araç bulunamadı')),
          body: const PageContent(
            children: [
              Text('Bu araç kaldırılmış veya başka bir hesaba ait olabilir.'),
            ],
          ),
        );
      }
      return VehicleFormScreen(key: ValueKey(vehicle.id), vehicle: vehicle);
    },
  );
}
