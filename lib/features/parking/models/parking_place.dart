import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingPlace {
  const ParkingPlace({
    required this.indoor,
    required this.savedAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.floor = '',
    this.section = '',
    this.space = '',
    this.notes = '',
    this.active = true,
  });
  final bool indoor, active;
  final DateTime savedAt;
  final double? latitude, longitude, accuracy;
  final String floor, section, space, notes;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get validCoordinates =>
      hasCoordinates &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180 &&
      accuracy != null &&
      accuracy!.isFinite &&
      accuracy! >= 0 &&
      accuracy! <= 100000;
  bool get valid =>
      notes.length <= 500 &&
      floor.length <= 30 &&
      section.length <= 30 &&
      space.length <= 30 &&
      (indoor
          ? floor.trim().isNotEmpty &&
                section.trim().isNotEmpty &&
                ((latitude == null && longitude == null && accuracy == null) ||
                    validCoordinates)
          : floor.isEmpty &&
                section.isEmpty &&
                space.isEmpty &&
                validCoordinates);
  String get description => indoor
      ? 'Kat: $floor • Bölüm: $section${space.isEmpty ? '' : ' • Yer: $space'}'
      : '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  Uri get mapUrl => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
  Uri get directionsUrl => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'walking',
    'dir_action': 'navigate',
  });
  Map<String, dynamic> toMap() => {
    'indoor': indoor,
    'active': active,
    'savedAt': Timestamp.fromDate(savedAt),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'floor': floor,
    'section': section,
    'space': space,
    'notes': notes,
  };
  factory ParkingPlace.fromMap(Map<String, dynamic> data) => ParkingPlace(
    indoor: data['indoor'] as bool,
    active: data['active'] as bool,
    savedAt: (data['savedAt'] as Timestamp).toDate(),
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    accuracy: (data['accuracy'] as num?)?.toDouble(),
    floor: data['floor'] as String,
    section: data['section'] as String,
    space: data['space'] as String,
    notes: data['notes'] as String,
  );
}
