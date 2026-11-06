import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../models/activity_record.dart';
import '../repositories/activity_repository.dart';
import '../repositories/offline_activity_repository.dart';
import '../repositories/queue_store.dart';
import 'package:firebase_auth/firebase_auth.dart';

final activityRepositoryProvider = Provider<ActivityRepository?>((ref) {
  final uid = ref.watch(
    signedInUserProvider.select((value) => value.asData?.value?.uid),
  );
  if (uid == null) return null;
  final db = FirebaseFirestore.instance;
  final repository = OfflineActivityRepository(
    backend: FirestoreActivityRepository(db, uid),
    store: deviceQueueStore(uid),
    newId: () => db.collection('users').doc().id,
    connection: db
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => !snapshot.metadata.isFromCache)
        .distinct(),
    active: () => FirebaseAuth.instance.currentUser?.uid == uid,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final offlineRecordStateProvider = StreamProvider<OfflineRecordState?>((ref) {
  final repository = ref.watch(activityRepositoryProvider);
  return repository is OfflineActivityRepository
      ? repository.states
      : Stream.value(null);
});
final activityRecordsProvider =
    StreamProvider.family<List<ActivityRecord>, String>(
      retry: (_, _) => null,
      (ref, vehicleId) =>
          ref.watch(activityRepositoryProvider)?.watch(vehicleId) ??
          Stream.value([]),
    );
