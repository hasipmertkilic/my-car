class Vehicle {
  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.fuelType,
    required this.transmission,
    required this.currentKm,
    this.engineCc = 1600,
  });
  final String id;
  final String brand;
  final String model;
  final int year;
  final String plate;
  final String fuelType;
  final String transmission;
  final int currentKm;
  final int engineCc;
  String get name => '$brand $model';

  Map<String, dynamic> toMap() => {
    'brand': brand,
    'model': model,
    'year': year,
    'plate': plate,
    'fuelType': fuelType,
    'transmission': transmission,
    'currentKm': currentKm,
    'engineCc': engineCc,
  };
  factory Vehicle.fromMap(String id, Map<String, dynamic> data) => Vehicle(
    id: id,
    brand: data['brand'] as String,
    model: data['model'] as String,
    year: data['year'] as int,
    plate: data['plate'] as String,
    fuelType: data['fuelType'] as String,
    transmission: data['transmission'] as String,
    currentKm: data['currentKm'] as int,
    engineCc: data['engineCc'] as int,
  );
}
