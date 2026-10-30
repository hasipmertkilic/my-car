abstract final class AuthValidation {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta adresini gir.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    return null;
  }

  static String? password(String? value, {bool registering = false}) {
    if (value == null || value.isEmpty) return 'Şifreni gir.';
    if (registering && value.length < 6) {
      return 'Şifren en az 6 karakter olmalı.';
    }
    return null;
  }
}
