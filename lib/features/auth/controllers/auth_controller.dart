import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_bootstrap.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ref.watch(firebaseAvailabilityProvider).ready
      ? FirebaseAuthRepository(FirebaseAuth.instance)
      : UnavailableAuthRepository(),
);

// Yönlendirici aynı nesneyi dinler; oturum değişiminde geçmiş yeniden oluşturulmaz.
final authSessionProvider = Provider<AuthSession>((ref) {
  final session = AuthSession(ref.watch(authRepositoryProvider));
  ref.onDispose(session.dispose);
  return session;
});

class AuthSession extends ChangeNotifier {
  AuthSession(this.repository) {
    retry();
  }
  final AuthRepository repository;
  StreamSubscription<AppUser?>? _subscription;
  AppUser? user;
  bool loading = true;
  String? error;

  void retry() {
    _subscription?.cancel();
    loading = true;
    error = null;
    notifyListeners();
    _subscription = repository.watchUser().listen(
      (value) {
        user = value;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object _) {
        user = null;
        loading = false;
        error =
            'Oturum kontrol edilemedi. Bağlantını kontrol edip tekrar dene.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
