import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class StationFailure implements Exception {
  const StationFailure(this.message);
  final String message;
}

class FuelStation {
  const FuelStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
  final String id, name, address;
  final double latitude, longitude;
  factory FuelStation.fromJson(Map<String, dynamic> json) => FuelStation(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
  Uri get directions => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
    'destination_place_id': id,
    'travelmode': 'driving',
  });
}

class StationService {
  StationService(this.client, this.token);
  final http.Client client;
  final Future<String?> Function() token;
  Future<List<FuelStation>> nearby(double latitude, double longitude) async {
    try {
      final credential = await token();
      if (credential == null) {
        throw const StationFailure('Oturumunu yenileyip tekrar dene.');
      }
      final response = await client
          .post(
            Uri.parse(
              const String.fromEnvironment(
                'STATIONS_ENDPOINT',
                defaultValue:
                    'https://us-central1-mycar-f0673.cloudfunctions.net/nearbyStations',
              ),
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $credential',
            },
            body: jsonEncode({
              'data': {'latitude': latitude, 'longitude': longitude},
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 404 || response.statusCode == 403) {
        throw const StationFailure(
          'İstasyon hizmeti henüz kullanıma hazır değil. Daha sonra tekrar dene.',
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['error'] != null) {
        final code = (body['error'] as Map?)?['status'];
        throw StationFailure(
          code == 'RESOURCE_EXHAUSTED'
              ? 'Çok sık arama yaptın. Biraz bekleyip tekrar dene.'
              : 'İstasyonlar şu anda alınamıyor. Biraz sonra tekrar dene.',
        );
      }
      return ((body['result'] as Map)['stations'] as List)
          .map(
            (item) =>
                FuelStation.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on StationFailure {
      rethrow;
    } catch (_) {
      throw const StationFailure(
        'İstasyonlar alınamadı. İnternet bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final stationServiceProvider = Provider<StationService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return StationService(
    client,
    () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  );
});
