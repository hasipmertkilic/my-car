import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../models/parking_place.dart';

class ParkingFailure implements Exception {
  const ParkingFailure(this.message);
  final String message;
}

abstract interface class ParkingRepository {
  Stream<ParkingPlace?> watch(String vehicleId);
  Stream<List<ParkingPlace>> watchHistory(String vehicleId);
  Future<void> save(String vehicleId, ParkingPlace place);
  Future<void> finish(String vehicleId);
}

class FirestoreParkingRepository implements ParkingRepository {
  FirestoreParkingRepository(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  @override
  Stream<List<ParkingPlace>> watchHistory(String vehicleId) => parent(vehicleId)
      .collection('parking')
      .doc('history')
      .snapshots()
      .map(
        (doc) => ((doc.data()?['entries'] as List?) ?? [])
            .map(
              (entry) =>
                  ParkingPlace.fromMap(Map<String, dynamic>.from(entry as Map)),
            )
            .toList(),
      );
  DocumentReference<Map<String, dynamic>> parent(String id) =>
      db.collection('users').doc(uid).collection('vehicles').doc(id);
  @override
  Stream<ParkingPlace?> watch(String vehicleId) => parent(vehicleId)
      .collection('parking')
      .doc('current')
      .snapshots()
      .map(
        (doc) => doc.exists && doc.data()?['active'] == true
            ? ParkingPlace.fromMap(doc.data()!)
            : null,
      );
  @override
  Future<void> save(String vehicleId, ParkingPlace place) async {
    if (!place.valid || !place.active) {
      throw const ParkingFailure('Park bilgilerini kontrol et.');
    }
    await _write(vehicleId, place);
  }

  @override
  Future<void> finish(String vehicleId) => _write(vehicleId, null);
  Future<void> _write(String vehicleId, ParkingPlace? place) async {
    try {
      final car = parent(vehicleId);
      final target = car.collection('parking').doc('current');
      final history = car.collection('parking').doc('history');
      await db.runTransaction((tx) async {
        final vehicle = await tx.get(car);
        final previous = await tx.get(target);
        final archive = place == null ? await tx.get(history) : null;
        if (!vehicle.exists || vehicle.data()?['archived'] == true) {
          throw const ParkingFailure('Bu araç artık garajında bulunmuyor.');
        }
        if (place == null) {
          if (previous.exists && previous.data()?['active'] == true) {
            final old = {...previous.data()!, 'active': false}
              ..remove('updatedAt');
            final entries = [
              old,
              ...((archive?.data()?['entries'] as List?) ?? []),
            ].take(5).toList();
            tx.set(history, {
              'entries': entries,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            tx.update(target, {
              'active': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          tx.set(target, {
            ...place.toMap(),
            'savedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException catch (_) {
      throw const ParkingFailure(
        'Park bilgisi kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final parkingRepositoryProvider = Provider<ParkingRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null || Firebase.apps.isEmpty
      ? null
      : FirestoreParkingRepository(FirebaseFirestore.instance, uid);
});
final parkingProvider = StreamProvider.family<ParkingPlace?, String>(
  retry: (_, _) => null,
  (ref, id) =>
      ref.watch(parkingRepositoryProvider)?.watch(id) ?? Stream.value(null),
);
final parkingHistoryProvider =
    StreamProvider.family<List<ParkingPlace>, String>(
      retry: (_, _) => null,
      (ref, id) =>
          ref.watch(parkingRepositoryProvider)?.watchHistory(id) ??
          Stream.value([]),
    );
