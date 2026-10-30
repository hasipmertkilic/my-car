import 'package:cloud_firestore/cloud_firestore.dart';

const maintenanceItems = {
  'engine_oil': 'Motor yağı',
  'oil_filter': 'Yağ filtresi',
  'air_filter': 'Hava filtresi',
  'cabin_filter': 'Polen / kabin filtresi',
  'fuel_filter': 'Yakıt filtresi',
  'spark_plugs': 'Bujiler',
  'brake_pads': 'Fren balataları',
  'brake_fluid': 'Fren hidroliği',
  'coolant': 'Antifriz / soğutma sıvısı',
  'transmission_oil': 'Şanzıman yağı',
  'timing_belt': 'Triger seti',
  'battery': 'Akü',
  'tires': 'Lastikler',
};

class MaintenanceEntry {
  const MaintenanceEntry({
    this.id = '',
    required this.date,
    required this.odometerKm,
    this.intervalKm = 10000,
    this.amountKurus = 0,
    this.items = const [],
    this.details = '',
    this.service = '',
    this.notes = '',
  });
  final String id, details, service, notes;
  final DateTime date;
  final int odometerKm, intervalKm, amountKurus;
  final List<String> items;
  int get nextKm => odometerKm + intervalKm;
  bool overdue(int currentKm) => currentKm > nextKm;
  bool approaching(int currentKm) => nextKm - currentKm <= 2000;
  String status(int currentKm) => overdue(currentKm)
      ? 'Periyodik bakım gecikti'
      : currentKm >= nextKm
      ? 'Periyodik bakım zamanı geldi'
      : approaching(currentKm)
      ? 'Periyodik bakım yaklaşıyor'
      : 'Bakım planın güncel';
  bool valid(DateTime now) =>
      !date.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59)) &&
      date.year >= 1900 &&
      odometerKm >= 0 &&
      odometerKm <= 10000000 &&
      intervalKm >= 1000 &&
      intervalKm <= 100000 &&
      amountKurus >= 0 &&
      amountKurus <= 100000000 &&
      items.length <= maintenanceItems.length &&
      items.toSet().length == items.length &&
      items.every(maintenanceItems.containsKey) &&
      (items.isNotEmpty || details.trim().isNotEmpty) &&
      details.length <= 2000 &&
      service.length <= 120 &&
      notes.length <= 1000;
  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'odometerKm': odometerKm,
    'intervalKm': intervalKm,
    'amountKurus': amountKurus,
    'items': items,
    'details': details,
    'service': service,
    'notes': notes,
  };
  factory MaintenanceEntry.fromMap(String id, Map<String, dynamic> data) =>
      MaintenanceEntry(
        id: id,
        date: (data['date'] as Timestamp).toDate(),
        odometerKm: data['odometerKm'] as int,
        intervalKm: data['intervalKm'] as int,
        amountKurus: data['amountKurus'] as int,
        items: List<String>.from(data['items'] as List),
        details: data['details'] as String,
        service: data['service'] as String,
        notes: data['notes'] as String,
      );
}

List<MaintenanceEntry> sortMaintenance(Iterable<MaintenanceEntry> entries) =>
    entries.toList()..sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date != 0 ? date : b.odometerKm.compareTo(a.odometerKm);
    });
