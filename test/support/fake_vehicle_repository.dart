import 'dart:async';
import 'package:my_car/features/vehicles/models/vehicle.dart';
import 'package:my_car/features/vehicles/repositories/vehicle_repository.dart';

const testVehicles = [
  Vehicle(
    id: 'bmw',
    brand: 'BMW',
    model: '320i',
    year: 2020,
    plate: '34 TEST 1',
    fuelType: 'Benzin',
    transmission: 'Otomatik',
    currentKm: 125430,
  ),
  Vehicle(
    id: 'clio',
    brand: 'Renault',
    model: 'Clio',
    year: 2022,
    plate: '34 TEST 2',
    fuelType: 'Dizel',
    transmission: 'Manuel',
    currentKm: 48200,
  ),
];

class FakeVehicleRepository implements VehicleRepository {
  FakeVehicleRepository({List<Vehicle> seed = const []}) : vehicles = [...seed];
  final List<Vehicle> vehicles;
  final Set<String> archived = {};
  String? activeId;
  String? failure;
  final changes = StreamController<List<Vehicle>>.broadcast(sync: true);
  final selections = StreamController<String?>.broadcast(sync: true);
  List<Vehicle> get visible =>
      vehicles.where((v) => !archived.contains(v.id)).toList();
  @override
  Stream<List<Vehicle>> watchVehicles() => Stream.multi((controller) {
    controller.add(visible);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = subscription.cancel;
  });
  @override
  Stream<String?> watchActiveId() => Stream.multi((controller) {
    controller.add(activeId);
    final subscription = selections.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> save(Vehicle vehicle) async {
    if (failure != null) throw VehicleFailure(failure!);
    final id = vehicle.id.isEmpty ? 'car-${vehicles.length}' : vehicle.id;
    vehicles.removeWhere((v) => v.id == id);
    vehicles.add(
      Vehicle(
        id: id,
        brand: vehicle.brand,
        model: vehicle.model,
        year: vehicle.year,
        plate: vehicle.plate,
        fuelType: vehicle.fuelType,
        transmission: vehicle.transmission,
        currentKm: vehicle.currentKm,
        engineCc: vehicle.engineCc,
      ),
    );
    activeId ??= id;
    changes.add(visible);
    selections.add(activeId);
  }

  @override
  Future<void> select(String id) async {
    if (failure != null) throw VehicleFailure(failure!);
    activeId = id;
    selections.add(activeId);
  }

  @override
  Future<void> archive(String id) async {
    archived.add(id);
    if (activeId == id) activeId = null;
    changes.add(visible);
    selections.add(activeId);
  }

  @override
  Future<void> restore(String id) async {
    archived.remove(id);
    changes.add(visible);
  }
}
