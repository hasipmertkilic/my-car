import 'dart:async';
import 'package:my_car/features/auth/models/app_user.dart';
import 'package:my_car/features/auth/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});
  AppUser? user;
  final changes = StreamController<AppUser?>.broadcast(sync: true);
  String? failure;
  String? lastEmail;
  String? lastPassword;
  int submissions = 0;
  Completer<void>? pending;

  @override
  Stream<AppUser?> watchUser() => Stream.multi((controller) {
    controller.add(user);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = subscription.cancel;
  });
  Future<void> _submit(String email, String password) async {
    submissions++;
    lastEmail = email;
    lastPassword = password;
    if (pending != null) await pending!.future;
    if (failure != null) throw AuthFailure(failure!);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _submit(email, password);
    user = AppUser(uid: 'test', email: email);
    changes.add(user);
  }

  @override
  Future<void> register(String email, String password) =>
      signIn(email, password);
  @override
  Future<void> resetPassword(String email) => _submit(email, '');
  @override
  Future<void> signOut() async {
    user = null;
    changes.add(null);
  }

  Future<void> dispose() => changes.close();
}
