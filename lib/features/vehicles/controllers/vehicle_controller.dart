import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/app_user.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';

final signedInUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);
final vehicleRepositoryProvider = Provider<VehicleRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null
      ? null
      : FirestoreVehicleRepository(FirebaseFirestore.instance, uid);
});
final vehiclesProvider = StreamProvider<List<Vehicle>>(
  retry: (_, _) => null,
  (ref) =>
      ref.watch(vehicleRepositoryProvider)?.watchVehicles() ?? Stream.value([]),
);
final activeVehicleIdProvider = StreamProvider<String?>(
  retry: (_, _) => null,
  (ref) =>
      ref.watch(vehicleRepositoryProvider)?.watchActiveId() ??
      Stream.value(null),
);
final activeVehicleProvider = Provider<Vehicle?>((ref) {
  final vehicles = ref.watch(vehiclesProvider).asData?.value ?? [];
  final id = ref.watch(activeVehicleIdProvider).asData?.value;
  if (vehicles.isEmpty) return null;
  return vehicles.where((vehicle) => vehicle.id == id).firstOrNull ??
      vehicles.first;
});
