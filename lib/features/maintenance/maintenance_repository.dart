import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../vehicles/controllers/vehicle_controller.dart';
import 'maintenance_entry.dart';

class MaintenanceFailure implements Exception {
  const MaintenanceFailure(this.message);
  final String message;
}

abstract interface class MaintenanceRepository {
  Stream<List<MaintenanceEntry>> watch(String vehicleId);
  Future<void> save(String vehicleId, MaintenanceEntry entry);
}

class FirestoreMaintenanceRepository implements MaintenanceRepository {
  FirestoreMaintenanceRepository(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> car(String id) =>
      db.collection('users').doc(uid).collection('vehicles').doc(id);
  @override
  Stream<List<MaintenanceEntry>> watch(String vehicleId) => car(vehicleId)
      .collection('maintenance')
      .snapshots()
      .map(
        (snapshot) => sortMaintenance(
          snapshot.docs.map(
            (doc) => MaintenanceEntry.fromMap(doc.id, doc.data()),
          ),
        ),
      );
  @override
  Future<void> save(String vehicleId, MaintenanceEntry entry) async {
    if (!entry.valid(DateTime.now())) {
      throw const MaintenanceFailure(
        'Bakım bilgilerini ve yapılan işlemleri kontrol et.',
      );
    }
    try {
      final parent = car(vehicleId);
      final collection = parent.collection('maintenance');
      final target = entry.id.isEmpty
          ? collection.doc()
          : collection.doc(entry.id);
      await db.runTransaction((transaction) async {
        final vehicle = await transaction.get(parent);
        final old = await transaction.get(target);
        if (!vehicle.exists || vehicle.data()?['archived'] != false) {
          throw const MaintenanceFailure('Araç artık garajında bulunmuyor.');
        }
        if (entry.odometerKm > (vehicle.data()!['currentKm'] as int)) {
          throw const MaintenanceFailure(
            'Bakım kilometresi güncel kilometreden büyük. Önce aracın güncel kilometresini düzenle.',
          );
        }
        if (entry.id.isNotEmpty && !old.exists) {
          throw const MaintenanceFailure(
            'Düzenlenecek bakım kaydı bulunamadı.',
          );
        }
        transaction.set(target, {
          ...entry.toMap(),
          'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw MaintenanceFailure(
        error.code == 'permission-denied'
            ? 'Bakım kaydı izni alınamadı. Hesabını ve bağlantını kontrol et.'
            : 'Bakım kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final maintenanceRepositoryProvider = Provider<MaintenanceRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null || Firebase.apps.isEmpty
      ? null
      : FirestoreMaintenanceRepository(FirebaseFirestore.instance, uid);
});
final maintenanceProvider =
    StreamProvider.family<List<MaintenanceEntry>, String>(
      retry: (_, _) => null,
      (ref, id) =>
          ref.watch(maintenanceRepositoryProvider)?.watch(id) ??
          Stream.value([]),
    );
