import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_record.dart';
import '../utils/record_calculations.dart';

class RecordFailure implements Exception {
  const RecordFailure(this.message);
  final String message;
}

abstract interface class ActivityRepository {
  Stream<List<ActivityRecord>> watch(String vehicleId);
  Future<void> save(String vehicleId, ActivityRecord record);
  Future<void> archive(String vehicleId, String id, bool archived);
}

class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> vehicle(String id) =>
      db.collection('users').doc(uid).collection('vehicles').doc(id);
  @override
  Stream<List<ActivityRecord>> watch(String vehicleId) => vehicle(vehicleId)
      .collection('activityRecords')
      .snapshots()
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

  Future<void> _mutate(
    String vehicleId, {
    ActivityRecord? record,
    String? id,
    bool archived = false,
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
      if ((record == null || record.id.isNotEmpty) &&
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
      );
    }
  }
}
