import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../models/inspection_schedule.dart';

class InspectionFailure implements Exception {
  const InspectionFailure(this.message);
  final String message;
}

abstract interface class InspectionRepository {
  Stream<InspectionSchedule?> watch(String vehicleId);
  Future<void> save(String vehicleId, InspectionSchedule schedule);
}

class FirestoreInspectionRepository implements InspectionRepository {
  FirestoreInspectionRepository(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> vehicle(String id) =>
      db.collection('users').doc(uid).collection('vehicles').doc(id);
  @override
  Stream<InspectionSchedule?> watch(String vehicleId) => vehicle(vehicleId)
      .collection('inspection')
      .doc('current')
      .snapshots()
      .map(
        (doc) => doc.exists ? InspectionSchedule.fromMap(doc.data()!) : null,
      );
  @override
  Future<void> save(String vehicleId, InspectionSchedule schedule) async {
    final today = DateTime.now();
    final lastDay = DateTime(
      schedule.lastDate.year,
      schedule.lastDate.month,
      schedule.lastDate.day,
    );
    if (schedule.intervalYears < 1 ||
        schedule.intervalYears > 5 ||
        lastDay.isAfter(today)) {
      throw const InspectionFailure(
        'Muayene tarihini ve 1–5 yıl aralığını kontrol et.',
      );
    }
    try {
      final parent = vehicle(vehicleId);
      final target = parent.collection('inspection').doc('current');
      await db.runTransaction((transaction) async {
        final car = await transaction.get(parent);
        final old = await transaction.get(target);
        if (!car.exists || car.data()?['archived'] == true) {
          throw const InspectionFailure('Bu araç artık garajında bulunmuyor.');
        }
        transaction.set(target, {
          ...schedule.toMap(),
          'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw InspectionFailure(
        error.code == 'permission-denied'
            ? 'Muayene kaydı izni alınamadı. Hesabını ve veritabanı kurallarını kontrol et.'
            : 'Muayene kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final inspectionRepositoryProvider = Provider<InspectionRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null
      ? null
      : FirestoreInspectionRepository(FirebaseFirestore.instance, uid);
});
final inspectionClockProvider = Provider<DateTime>((ref) => DateTime.now());
final inspectionProvider = StreamProvider.family<InspectionSchedule?, String>(
  retry: (_, _) => null,
  (ref, vehicleId) =>
      ref.watch(inspectionRepositoryProvider)?.watch(vehicleId) ??
      Stream.value(null),
);
