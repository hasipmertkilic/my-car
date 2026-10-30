import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../models/activity_record.dart';
import '../repositories/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null
      ? null
      : FirestoreActivityRepository(FirebaseFirestore.instance, uid);
});
final activityRecordsProvider =
    StreamProvider.family<List<ActivityRecord>, String>(
      retry: (_, _) => null,
      (ref, vehicleId) =>
          ref.watch(activityRepositoryProvider)?.watch(vehicleId) ??
          Stream.value([]),
    );
