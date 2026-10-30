import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';

class VehicleFailure implements Exception {
  const VehicleFailure(this.message);
  final String message;
}

abstract interface class VehicleRepository {
  Stream<List<Vehicle>> watchVehicles();
  Stream<String?> watchActiveId();
  Future<void> save(Vehicle vehicle);
  Future<void> select(String id);
  Future<void> archive(String id);
  Future<void> restore(String id);
}

class FirestoreVehicleRepository implements VehicleRepository {
  FirestoreVehicleRepository(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  DocumentReference<Map<String, dynamic>> get profile =>
      db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get vehicles =>
      profile.collection('vehicles');

  @override
  Stream<List<Vehicle>> watchVehicles() => vehicles.snapshots().map((snapshot) {
    final result = snapshot.docs
        .where((doc) => doc.data()['archived'] != true)
        .map((doc) => Vehicle.fromMap(doc.id, doc.data()))
        .toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  });
  @override
  Stream<String?> watchActiveId() => profile.snapshots().map(
    (doc) => doc.data()?['activeVehicleId'] as String?,
  );

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (error) {
      throw VehicleFailure(switch (error.code) {
        'permission-denied' =>
          'Araç kayıtlarına erişilemiyor. Hesabını ve Firestore izinlerini kontrol et.',
        'unavailable' || 'deadline-exceeded' =>
          'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
        _ => 'Araç işlemi tamamlanamadı. Lütfen tekrar dene.',
      });
    }
  }

  @override
  Future<void> save(Vehicle vehicle) => _run(
    () => db.runTransaction((transaction) async {
      final target = vehicle.id.isEmpty
          ? vehicles.doc()
          : vehicles.doc(vehicle.id);
      final user = await transaction.get(profile);
      final previous = await transaction.get(target);
      if (vehicle.id.isNotEmpty &&
          (!previous.exists || previous.data()?['archived'] == true)) {
        throw const VehicleFailure(
          'Bu araç artık mevcut değil. Garajını yenile.',
        );
      }
      if (vehicle.currentKm < (previous.data()?['recordMaxKm'] as int? ?? 0)) {
        throw const VehicleFailure(
          'Kilometre, işlem geçmişindeki en yüksek kilometreden küçük olamaz. Yanlış kaydı Kayıtlar ekranından düzelt.',
        );
      }
      transaction.set(target, {
        ...vehicle.toMap(),
        'baselineKm': vehicle.currentKm,
        'archived': false,
        'createdAt':
            previous.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (user.data()?['activeVehicleId'] == null) {
        transaction.set(profile, {
          'activeVehicleId': target.id,
        }, SetOptions(merge: true));
      }
    }),
  );
  @override
  Future<void> select(String id) => _run(
    () => db.runTransaction((transaction) async {
      final vehicle = await transaction.get(vehicles.doc(id));
      if (!vehicle.exists || vehicle.data()?['archived'] == true) {
        throw const VehicleFailure('Araç bulunamadı.');
      }
      transaction.set(profile, {
        'activeVehicleId': id,
      }, SetOptions(merge: true));
    }),
  );
  // Yumuşak silme: araç geçmişi ve gelecekteki belgeler yetim kalmaz.
  // Kullanıcı aynı oturumda geri alabilir; veri kalıcı olarak silinmez.
  @override
  Future<void> archive(String id) => _run(
    () => db.runTransaction((transaction) async {
      final user = await transaction.get(profile);
      final vehicle = await transaction.get(vehicles.doc(id));
      if (!vehicle.exists) throw const VehicleFailure('Araç bulunamadı.');
      transaction.update(vehicles.doc(id), {
        'archived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (user.data()?['activeVehicleId'] == id) {
        transaction.set(profile, {
          'activeVehicleId': null,
        }, SetOptions(merge: true));
      }
    }),
  );
  @override
  Future<void> restore(String id) => _run(
    () => db.runTransaction((transaction) async {
      final vehicle = await transaction.get(vehicles.doc(id));
      if (!vehicle.exists) throw const VehicleFailure('Araç bulunamadı.');
      transaction.update(vehicles.doc(id), {
        'archived': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }),
  );
}
