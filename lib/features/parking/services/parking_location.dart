import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/parking_place.dart';
import '../repositories/parking_repository.dart';

class ParkCoordinates {
  const ParkCoordinates(this.latitude, this.longitude, this.accuracy);
  final double latitude, longitude, accuracy;
}

abstract interface class ParkingLocation {
  Future<ParkCoordinates> locate();
  Future<bool> openMap(ParkingPlace place);
  Future<bool> navigateToCar(ParkingPlace place);
}

class DeviceParkingLocation implements ParkingLocation {
  @override
  Future<ParkCoordinates> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ParkingFailure('Konum servisini açıp tekrar dene.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ParkingFailure(
          'Konum izni verilmedi. Uygulama veya tarayıcı ayarlarından izin verip tekrar dene.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return ParkCoordinates(
        position.latitude,
        position.longitude,
        position.accuracy,
      );
    } on ParkingFailure {
      rethrow;
    } catch (_) {
      throw const ParkingFailure('Konum alınamadı. Açık alanda tekrar dene.');
    }
  }

  @override
  Future<bool> openMap(ParkingPlace place) => launchUrl(
    place.mapUrl,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  @override
  Future<bool> navigateToCar(ParkingPlace place) async {
    if (!place.hasCoordinates) {
      throw const ParkingFailure('Bu park kaydında harita konumu bulunmuyor.');
    }
    // Başlangıç verilmez: Google Maps açıldığı andaki cihaz konumunu kullanır.
    return launchUrl(
      place.directionsUrl,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }
}

final parkingLocationProvider = Provider<ParkingLocation>(
  (ref) => DeviceParkingLocation(),
);
