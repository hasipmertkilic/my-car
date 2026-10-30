import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../vehicles/controllers/vehicle_controller.dart';
import 'expertise_record.dart';

class ExpertiseFailure implements Exception {
  const ExpertiseFailure(this.message);
  final String message;
}

abstract interface class ExpertiseRepository {
  Stream<ExpertiseRecord?> watch(String vehicleId);
  Future<void> save(String vehicleId, ExpertiseRecord record);
  Future<String> upload(String vehicleId, Uint8List bytes);
  Future<Uint8List> readPdf(String vehicleId, String reportId);
  Future<void> removePdf(String vehicleId, String reportId);
}

class FirebaseExpertiseRepository implements ExpertiseRepository {
  FirebaseExpertiseRepository(this.db, this.storage, this.uid);
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  final String uid;
  DocumentReference<Map<String, dynamic>> car(String id) =>
      db.collection('users').doc(uid).collection('vehicles').doc(id);
  Reference pdf(String id, String reportId) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(reportId)) {
      throw const ExpertiseFailure('Rapor bulunamadı.');
    }
    return storage.ref('users/$uid/vehicles/$id/expertise/$reportId.pdf');
  }

  @override
  Stream<ExpertiseRecord?> watch(String vehicleId) => car(vehicleId)
      .collection('expertise')
      .doc('current')
      .snapshots()
      .map((doc) => doc.exists ? ExpertiseRecord.fromMap(doc.data()!) : null);
  @override
  Future<void> save(String vehicleId, ExpertiseRecord record) async {
    if (!record.valid) {
      throw const ExpertiseFailure('Ekspertiz bilgilerini kontrol et.');
    }
    final parent = car(vehicleId);
    final target = parent.collection('expertise').doc('current');
    await db.runTransaction((tx) async {
      final vehicle = await tx.get(parent);
      final old = await tx.get(target);
      if (!vehicle.exists || vehicle.data()?['archived'] != false) {
        throw const ExpertiseFailure('Araç artık garajında değil.');
      }
      tx.set(target, {
        ...record.toMap(),
        'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<String> upload(String vehicleId, Uint8List bytes) async {
    if (!isExpertisePdf(bytes)) {
      throw const ExpertiseFailure('En fazla 10 MB büyüklüğünde bir PDF seç.');
    }
    final id = db.collection('_ids').doc().id;
    await pdf(
      vehicleId,
      id,
    ).putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    return id;
  }

  @override
  Future<Uint8List> readPdf(String vehicleId, String reportId) async {
    final data = await pdf(vehicleId, reportId).getData(maxExpertisePdfBytes);
    if (data == null || !isExpertisePdf(data)) {
      throw const ExpertiseFailure('PDF raporu okunamadı.');
    }
    return data;
  }

  @override
  Future<void> removePdf(String vehicleId, String reportId) =>
      pdf(vehicleId, reportId).delete();
}

final expertiseRepositoryProvider = Provider<ExpertiseRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null || Firebase.apps.isEmpty
      ? null
      : FirebaseExpertiseRepository(
          FirebaseFirestore.instance,
          FirebaseStorage.instance,
          uid,
        );
});
final expertiseProvider = StreamProvider.family<ExpertiseRecord?, String>(
  retry: (_, _) => null,
  (ref, id) =>
      ref.watch(expertiseRepositoryProvider)?.watch(id) ?? Stream.value(null),
);
