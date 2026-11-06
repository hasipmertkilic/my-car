import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'journey_models.dart';

class JourneyFailure implements Exception {
  const JourneyFailure(this.message);
  final String message;
}

class JourneyService {
  JourneyService(this.client, this.token);
  final http.Client client;
  final Future<String?> Function() token;
  Future<List<JourneyRoute>> plan(
    JourneyWaypoint origin,
    JourneyWaypoint destination, {
    required bool avoidTolls,
  }) async {
    try {
      final credential = await token();
      if (credential == null) {
        throw const JourneyFailure('Oturumunu yenileyip tekrar dene.');
      }
      final response = await client
          .post(
            Uri.parse(
              const String.fromEnvironment(
                'JOURNEYS_ENDPOINT',
                defaultValue:
                    'https://us-central1-mycar-f0673.cloudfunctions.net/planRoutes',
              ),
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $credential',
            },
            body: jsonEncode({
              'data': {
                'origin': origin.toJson(),
                'destination': destination.toJson(),
                'avoidTolls': avoidTolls,
              },
            }),
          )
          .timeout(const Duration(seconds: 35));
      if (response.statusCode == 404 || response.statusCode == 403) {
        throw const JourneyFailure(
          'Rota hizmeti henüz kullanıma hazır değil. Daha sonra tekrar dene.',
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['error'] != null) {
        final status = (body['error'] as Map?)?['status'];
        throw JourneyFailure(switch (status) {
          'RESOURCE_EXHAUSTED' =>
            'Çok sık rota aradın veya günlük sınıra ulaştın. Biraz sonra tekrar dene.',
          'FAILED_PRECONDITION' =>
            'Rota hizmeti henüz etkin değil. Daha sonra tekrar dene.',
          'INVALID_ARGUMENT' => 'Başlangıç ve varış konumlarını kontrol et.',
          'UNAUTHENTICATED' => 'Oturumunu yenileyip tekrar dene.',
          _ => 'Rota hesaplanamadı. Başlangıç ve varış adreslerini kontrol et.',
        });
      }
      final values = ((body['result'] as Map)['routes'] as List)
          .map(
            (value) =>
                JourneyRoute.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
      if (values.isEmpty) {
        throw const JourneyFailure(
          'Bu iki konum arasında sürüş rotası bulunamadı. Farklı bir başlangıç veya varış seç.',
        );
      }
      return values;
    } on JourneyFailure {
      rethrow;
    } catch (_) {
      throw const JourneyFailure(
        'Rota alınamadı. İnternet bağlantını kontrol edip tekrar dene.',
      );
    }
  }
}

final journeyServiceProvider = Provider<JourneyService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return JourneyService(
    client,
    () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  );
});
