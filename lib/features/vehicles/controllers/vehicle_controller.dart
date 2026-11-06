import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/app_user.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import '../../records/controllers/activity_controller.dart';

final signedInUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);
final vehicleRepositoryProvider = Provider<VehicleRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null
      ? null
      : FirestoreVehicleRepository(FirebaseFirestore.instance, uid);
});
final vehiclesProvider = StreamProvider<List<Vehicle>>(retry: (_, _) => null, (
  ref,
) {
  final pending =
      ref.watch(offlineRecordStateProvider).asData?.value?.pending ?? [];
  return ref
          .watch(vehicleRepositoryProvider)
          ?.watchVehicles()
          .map(
            (vehicles) => vehicles.map((vehicle) {
              final km = pending
                  .where(
                    (op) => op.vehicleId == vehicle.id && op.archived != true,
                  )
                  .fold<int>(
                    vehicle.currentKm,
                    (value, op) => op.record.odometerKm > value
                        ? op.record.odometerKm
                        : value,
                  );
              return km == vehicle.currentKm
                  ? vehicle
                  : Vehicle.fromMap(vehicle.id, {
                      ...vehicle.toMap(),
                      'currentKm': km,
                    });
            }).toList(),
          ) ??
      Stream.value([]);
});
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
