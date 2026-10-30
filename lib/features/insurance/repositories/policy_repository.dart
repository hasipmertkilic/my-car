import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../models/insurance_policy.dart';

class PolicyFailure implements Exception {
  const PolicyFailure(this.message);
  final String message;
}

abstract interface class PolicyRepository {
  Stream<List<InsurancePolicy>> watch(String vehicleId);
  Future<void> save(String vehicleId, InsurancePolicy policy);
  Future<void> archive(String vehicleId, String id, {bool archived = true});
}

class FirestorePolicyRepository implements PolicyRepository {
  FirestorePolicyRepository(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> car(String id) =>
      db.collection('users').doc(uid).collection('vehicles').doc(id);
  @override
  Stream<List<InsurancePolicy>> watch(String vehicleId) =>
      car(vehicleId).collection('policies').snapshots().map((snapshot) {
        final policies =
            snapshot.docs
                .map((doc) => InsurancePolicy.fromMap(doc.id, doc.data()))
                .where((p) => !p.archived)
                .toList()
              ..sort((a, b) => b.endDate.compareTo(a.endDate));
        return policies;
      });
  @override
  Future<void> save(String vehicleId, InsurancePolicy policy) async {
    if (!policy.valid || policy.archived) {
      throw const PolicyFailure(
        'Poliçe bilgilerini ve tarih aralığını kontrol et.',
      );
    }
    final parent = car(vehicleId);
    final target = policy.id.isEmpty
        ? parent.collection('policies').doc()
        : parent.collection('policies').doc(policy.id);
    try {
      await db.runTransaction((tx) async {
        final vehicle = await tx.get(parent);
        final previous = await tx.get(target);
        if (!vehicle.exists || vehicle.data()?['archived'] == true) {
          throw const PolicyFailure('Bu araç artık garajında bulunmuyor.');
        }
        if (policy.id.isNotEmpty &&
            (!previous.exists || previous.data()?['archived'] == true)) {
          throw const PolicyFailure('Poliçe artık listende bulunmuyor.');
        }
        tx.set(target, {
          ...policy.toMap(),
          'createdAt':
              previous.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (_) {
      throw const PolicyFailure(
        'Poliçe kaydedilemedi. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }

  @override
  Future<void> archive(
    String vehicleId,
    String id, {
    bool archived = true,
  }) async {
    try {
      await car(vehicleId).collection('policies').doc(id).update({
        'archived': archived,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (_) {
      throw const PolicyFailure(
        'Poliçe güncellenemedi. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final policyRepositoryProvider = Provider<PolicyRepository?>((ref) {
  final uid = ref.watch(signedInUserProvider).asData?.value?.uid;
  return uid == null || Firebase.apps.isEmpty
      ? null
      : FirestorePolicyRepository(FirebaseFirestore.instance, uid);
});
final policiesProvider = StreamProvider.family<List<InsurancePolicy>, String>(
  retry: (_, _) => null,
  (ref, id) =>
      ref.watch(policyRepositoryProvider)?.watch(id) ?? Stream.value([]),
);
