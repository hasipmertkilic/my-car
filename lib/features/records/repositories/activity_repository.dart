import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_record.dart';
import '../utils/record_calculations.dart';

class RecordFailure implements Exception {
  const RecordFailure(this.message, {this.retryable = false});
  final String message;
  final bool retryable;
}

abstract interface class ActivityRepository {
  Stream<List<ActivityRecord>> watch(String vehicleId);
  Future<void> save(String vehicleId, ActivityRecord record);
  Future<void> archive(String vehicleId, String id, bool archived);
}

abstract interface class QueuedActivityBackend implements ActivityRepository {
  Future<void> saveQueued(
    String vehicleId,
    ActivityRecord record, {
    required bool create,
    required String? base,
  });
  Future<void> archiveQueued(
    String vehicleId,
    ActivityRecord record,
    bool archived,
  );
}

class FirestoreActivityRepository implements QueuedActivityBackend {
  FirestoreActivityRepository(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> vehicle(String id) =>
      db.collection('users').doc(uid).collection('vehicles').doc(id);
  @override
  Stream<List<ActivityRecord>> watch(String vehicleId) => vehicle(vehicleId)
      .collection('activityRecords')
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache || snapshot.docs.isNotEmpty,
      )
      .map((snapshot) {
        final records = snapshot.docs
            .where((doc) => doc.data()['archived'] != true)
            .map((doc) => ActivityRecord.fromMap(doc.id, doc.data()))
            .toList();
        records.sort((a, b) => RecordCalculations.compare(b, a));
        return records;
      });
  @override
  Future<void> save(String vehicleId, ActivityRecord record) =>
      _mutate(vehicleId, record: record);
  @override
  Future<void> archive(String vehicleId, String id, bool archived) =>
      _mutate(vehicleId, id: id, archived: archived);
  @override
  Future<void> saveQueued(
    String vehicleId,
    ActivityRecord record, {
    required bool create,
    required String? base,
  }) => _mutate(
    vehicleId,
    record: record,
    queued: true,
    create: create,
    base: base,
  );
  @override
  Future<void> archiveQueued(
    String vehicleId,
    ActivityRecord record,
    bool archived,
  ) => _mutate(
    vehicleId,
    id: record.id,
    archived: archived,
    queued: true,
    base: record.fingerprint,
  );

  Future<void> _mutate(
    String vehicleId, {
    ActivityRecord? record,
    String? id,
    bool archived = false,
    bool queued = false,
    bool create = false,
    String? base,
  }) async {
    try {
      final parent = vehicle(vehicleId);
      // Tüm geçmişin tutarlı bir sürümünü al; transaction sürümü değişmişse
      // kaydı reddeder. Eş zamanlı girişler birbirinin kilometre hesabını ezmez.
      final before = await parent.get(const GetOptions(source: Source.server));
      final revision = before.data()?['activityRevision'] ?? 0;
      final collection = parent.collection('activityRecords');
      final snapshot = await collection.get(
        const GetOptions(source: Source.server),
      );
      final target = record != null && record.id.isEmpty
          ? collection.doc()
          : collection.doc(record?.id ?? id!);
      final old = snapshot.docs.where((doc) => doc.id == target.id).firstOrNull;
      if (queued && old != null) {
        final previous = ActivityRecord.fromMap(old.id, old.data());
        final desired = record?.fingerprint ?? base;
        if (previous.fingerprint == desired &&
            old.data()['archived'] == (record == null ? archived : false)) {
          return;
        }
        if (create || previous.fingerprint != base) {
          throw const RecordFailure(
            'Bu kayıt başka bir cihazda değişti. Bekleyen kaydı kontrol et.',
          );
        }
      }
      if ((record == null || (record.id.isNotEmpty && !create)) &&
          (old == null || (record != null && old.data()['archived'] == true))) {
        throw const RecordFailure('Kayıt artık mevcut değil. Listeyi yenile.');
      }
      final candidate = record ?? ActivityRecord.fromMap(old!.id, old.data());
      final records = snapshot.docs
          .where((doc) => doc.id != target.id && doc.data()['archived'] != true)
          .map((doc) => ActivityRecord.fromMap(doc.id, doc.data()))
          .toList();
      if (!archived) records.add(candidate);
      final invalid = RecordCalculations.validateTimeline(records);
      if (invalid != null) throw RecordFailure(invalid);
      final maxKm = records.fold<int>(
        0,
        (value, r) => max(value, r.odometerKm),
      );
      await db.runTransaction((transaction) async {
        final latest = await transaction.get(parent);
        final previous = await transaction.get(target);
        final data = latest.data();
        if (data == null || data['archived'] == true) {
          throw const RecordFailure('Araç kaldırılmış. Garajına dön.');
        }
        if ((data['activityRevision'] ?? 0) != revision) {
          throw const RecordFailure(
            'Araç geçmişi başka bir işlemle güncellendi. Tekrar kaydet.',
            retryable: true,
          );
        }
        if (record != null) {
          transaction.set(target, {
            ...record.toMap(),
            'archived': false,
            'createdAt':
                previous.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(target, {
            'archived': archived,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        final baseline = data['baselineKm'] as int? ?? data['currentKm'] as int;
        transaction.update(parent, {
          'baselineKm': baseline,
          'recordMaxKm': maxKm,
          'activityRevision': (revision as int) + 1,
          'currentKm': max(baseline, maxKm),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw RecordFailure(
        error.code == 'permission-denied'
            ? 'Kayıt izni alınamadı. Hesabını ve Firestore kurallarını kontrol et.'
            : 'Kayıt işlemi tamamlanamadı. İnternetini kontrol edip tekrar dene.',
        retryable: [
          'unavailable',
          'deadline-exceeded',
          'aborted',
          'network-request-failed',
        ].contains(error.code),
      );
    }
  }
}
