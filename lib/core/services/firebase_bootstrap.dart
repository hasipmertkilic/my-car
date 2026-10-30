import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

// Gerçek MyCar projesinin platform seçenekleri FlutterFire tarafından üretilir.
Future<FirebaseAvailability> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
    return const FirebaseAvailability();
  } catch (_) {
    return const FirebaseAvailability(
      error:
          'Firebase başlatılamadı. Bağlantı yapılandırmasını kontrol edip uygulamayı yeniden aç.',
    );
  }
}
