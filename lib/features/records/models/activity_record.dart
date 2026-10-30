import 'package:cloud_firestore/cloud_firestore.dart';

const expenseCategories = [
  'Bakım',
  'Tamir',
  'Lastik',
  'Sigorta',
  'Kasko',
  'Muayene',
  'Otopark',
  'Yıkama',
  'Diğer',
];

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.kind,
    required this.date,
    required this.odometerKm,
    required this.amountKurus,
    required this.category,
    this.litersMilli = 0,
    this.fullTank = false,
    this.fuelType = '',
    this.notes = '',
  });
  final String id;
  final String kind;
  final DateTime date;
  final int odometerKm;
  final int amountKurus;
  final String category;
  final int litersMilli;
  final bool fullTank;
  final String fuelType;
  final String notes;
  bool get isFuel => kind == 'fuel';
  double get liters => litersMilli / 1000;
  double get amount => amountKurus / 100;
  double? get pricePerLiter => litersMilli > 0 ? amount / liters : null;
  String get title => isFuel ? '$fuelType alımı' : category;
  Map<String, dynamic> toMap() => {
    'kind': kind,
    'date': Timestamp.fromDate(date),
    'odometerKm': odometerKm,
    'amountKurus': amountKurus,
    'category': category,
    'litersMilli': litersMilli,
    'fullTank': fullTank,
    'fuelType': fuelType,
    'notes': notes,
  };
  factory ActivityRecord.fromMap(String id, Map<String, dynamic> data) =>
      ActivityRecord(
        id: id,
        kind: data['kind'] as String,
        date: (data['date'] as Timestamp).toDate(),
        odometerKm: data['odometerKm'] as int,
        amountKurus: data['amountKurus'] as int,
        category: data['category'] as String,
        litersMilli: data['litersMilli'] as int,
        fullTank: data['fullTank'] as bool,
        fuelType: data['fuelType'] as String,
        notes: data['notes'] as String,
      );
}
