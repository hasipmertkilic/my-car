import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/firebase_bootstrap.dart';
import '../controllers/auth_controller.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../utils/auth_validation.dart';

enum AuthPage { login, register, reset }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.page});
  final AuthPage page;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  bool hidePassword = true;
  String? error;
  bool resetSent = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy ||
        !ref.read(firebaseAvailabilityProvider).ready ||
        !formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      resetSent = false;
    });
    final repository = ref.read(authRepositoryProvider);
    try {
      switch (widget.page) {
        case AuthPage.login:
          await repository.signIn(
            normalizeAuthEmail(email.text),
            password.text,
          );
        case AuthPage.register:
          await repository.register(
            normalizeAuthEmail(email.text),
            password.text,
          );
        case AuthPage.reset:
          await repository.resetPassword(normalizeAuthEmail(email.text));
      }
      if (mounted && widget.page == AuthPage.reset) {
        setState(() => resetSent = true);
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'İşlem tamamlanamadı. Lütfen tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(firebaseAvailabilityProvider);
    final registering = widget.page == AuthPage.register;
    final resetting = widget.page == AuthPage.reset;
    final title = resetting
        ? 'Şifreni yenile'
        : registering
        ? 'Hesabını oluştur'
        : 'Tekrar hoş geldin';
    final subtitle = resetting
        ? 'Şifreni yenilemek için e-posta adresini gir.'
        : registering
        ? 'Aracının hikâyesini birlikte takip edelim.'
        : 'Aracınla ilgili her şey bir arada.';
    final button = resetting
        ? 'Sıfırlama bağlantısı gönder'
        : registering
        ? 'Kaydol'
        : 'Giriş yap';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.directions_car_filled_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'My Car',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(subtitle),
                      const SizedBox(height: 24),
                      if (!availability.ready) ...[
                        _Message(availability.error!, isError: true),
                        const SizedBox(height: 18),
                      ],
                      TextFormField(
                        controller: email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: resetting
                            ? TextInputAction.done
                            : TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: AuthValidation.email,
                        onFieldSubmitted: resetting ? (_) => submit() : null,
                      ),
                      if (!resetting) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: password,
                          enabled: !busy,
                          obscureText: hidePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: [
                            registering
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: registering
                              ? TextInputAction.next
                              : TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hidePassword
                                  ? 'Şifreyi göster'
                                  : 'Şifreyi gizle',
                              onPressed: busy
                                  ? null
                                  : () => setState(
                                      () => hidePassword = !hidePassword,
                                    ),
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => AuthValidation.password(
                            value,
                            registering: registering,
                          ),
                          onFieldSubmitted: registering
                              ? null
                              : (_) => submit(),
                        ),
                      ],
                      if (registering) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmation,
                          enabled: !busy,
                          obscureText: hidePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Şifre tekrar',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Şifreni tekrar gir.'
                              : value != password.text
                              ? 'Şifreler eşleşmiyor.'
                              : null,
                          onFieldSubmitted: (_) => submit(),
                        ),
                      ],
                      if (!registering && !resetting)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: busy
                                ? null
                                : () => context.go('/forgot-password'),
                            child: const Text('Şifremi unuttum'),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (error != null) ...[
                        _Message(error!, isError: true),
                        const SizedBox(height: 16),
                      ],
                      if (resetSent) ...[
                        const _Message(
                          'Bu adresle kayıtlı bir hesap varsa şifre sıfırlama bağlantısı gönderildi. Gelen kutunu ve spam klasörünü kontrol et.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        onPressed: busy || !availability.ready ? null : submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(button),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.go(
                                registering || resetting
                                    ? '/login'
                                    : '/register',
                              ),
                        child: Text(
                          resetting
                              ? 'Giriş ekranına dön'
                              : registering
                              ? 'Hesabın var mı? Giriş yap'
                              : 'Hesabın yok mu? Kaydol',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Araç bilgilerin kişisel hesabında saklanır.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.isError = false});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError
              ? Theme.of(context).colorScheme.onErrorContainer
              : Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    ),
  );
}
