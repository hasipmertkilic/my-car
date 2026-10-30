class AppUser {
  const AppUser({required this.uid, required this.email});
  final String uid;
  final String email;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}
