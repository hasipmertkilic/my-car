import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

String normalizeAuthEmail(String email) => email.trim().toLowerCase();

abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this.auth);
  final FirebaseAuth auth;

  @override
  Stream<AppUser?> watchUser() => auth.authStateChanges().map(
    (user) =>
        user == null ? null : AppUser(uid: user.uid, email: user.email ?? ''),
  );

  Future<void> _run(
    Future<void> Function() action, {
    bool hideMissingUser = false,
  }) async {
    try {
      await auth.setLanguageCode('tr');
      await action();
    } on FirebaseAuthException catch (error) {
      if (hideMissingUser && error.code == 'user-not-found') return;
      throw AuthFailure(switch (error.code) {
        'invalid-email' => 'Geçerli bir e-posta adresi gir.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'E-posta veya şifre hatalı.',
        'email-already-in-use' =>
          'Bu e-posta zaten kayıtlı. Giriş yapabilir veya şifreni sıfırlayabilirsin.',
        'weak-password' =>
          'Şifren Firebase projesinin güvenlik koşullarını karşılamıyor. Daha güçlü bir şifre seç.',
        'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
        'too-many-requests' =>
          'Çok fazla deneme yaptın. Biraz bekleyip tekrar dene.',
        'network-request-failed' =>
          'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
        'operation-not-allowed' =>
          'Firebase projesinde e-posta/şifre ile giriş etkinleştirilmeli.',
        'invalid-api-key' ||
        'app-not-authorized' => 'Firebase uygulama yapılandırması geçersiz.',
        _ => 'İşlem tamamlanamadı. Lütfen tekrar dene.',
      });
    } catch (_) {
      throw const AuthFailure(
        'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.',
      );
    }
  }

  @override
  Future<void> signIn(String email, String password) => _run(() async {
    await auth.signInWithEmailAndPassword(
      email: normalizeAuthEmail(email),
      password: password,
    );
  });
  @override
  Future<void> register(String email, String password) => _run(() async {
    await auth.createUserWithEmailAndPassword(
      email: normalizeAuthEmail(email),
      password: password,
    );
  });
  @override
  Future<void> resetPassword(String email) => _run(
    () => auth.sendPasswordResetEmail(email: normalizeAuthEmail(email)),
    hideMissingUser: true,
  );

  @override
  Future<void> signOut() => _run(auth.signOut);
}

class UnavailableAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> watchUser() => Stream.value(null);
  Future<void> _unavailable() async =>
      throw const AuthFailure('Firebase bağlantısı henüz hazır değil.');
  @override
  Future<void> signIn(String email, String password) => _unavailable();
  @override
  Future<void> register(String email, String password) => _unavailable();
  @override
  Future<void> resetPassword(String email) => _unavailable();
  @override
  Future<void> signOut() => _unavailable();
}
