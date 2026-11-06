import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase_options.dart';

class FirebaseAvailability {
  const FirebaseAvailability({this.error});
  final String? error;
  bool get ready => error == null;
}

final firebaseAvailabilityProvider = Provider<FirebaseAvailability>(
  (ref) => const FirebaseAvailability(
    error: 'Firebase bağlantısı henüz yapılandırılmadı.',
  ),
);

// Android already initializes the default app from google-services.json.
// Reuse that configuration instead of supplying a second set of Dart options.
FirebaseOptions? firebaseStartupOptions({
  required bool web,
  required TargetPlatform platform,
}) {
  if (!web && platform == TargetPlatform.android) return null;
  if (web) return DefaultFirebaseOptions.web;
  return DefaultFirebaseOptions.currentPlatform;
}

String firebaseStartupError(Object error) {
  if (error is FirebaseException &&
      RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(error.code)) {
    return 'Firebase bağlantısı başlatılamadı. Uygulamayı yeniden aç. '
        'Sorun sürerse hata kodunu paylaş: ${error.code}';
  }
  return 'Firebase başlatılamadı. Uygulamayı yeniden açıp tekrar dene.';
}

Future<FirebaseAvailability> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: firebaseStartupOptions(
        web: kIsWeb,
        platform: defaultTargetPlatform,
      ),
    );
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          webPersistentTabManager: WebPersistentMultipleTabManager(),
        );
      } catch (_) {
        // Browsers without persistent storage can still use the current session.
      }
    } else {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    }
    return const FirebaseAvailability();
  } catch (error) {
    return FirebaseAvailability(error: firebaseStartupError(error));
  }
}
