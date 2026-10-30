import 'package:my_car/features/inspection/repositories/inspection_repository.dart';
import 'support/fake_inspection_repository.dart';
import 'package:my_car/features/records/controllers/activity_controller.dart';
import 'support/fake_activity_repository.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/app/app.dart';
import 'package:my_car/app/router.dart';
import 'package:my_car/core/services/firebase_bootstrap.dart';
import 'package:my_car/features/auth/controllers/auth_controller.dart';
import 'package:my_car/features/auth/models/app_user.dart';
import 'package:my_car/features/auth/repositories/auth_repository.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_vehicle_repository.dart';
import 'package:my_car/features/vehicles/controllers/vehicle_controller.dart';

Future<ProviderContainer> start(
  WidgetTester tester,
  FakeAuthRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inspectionRepositoryProvider.overrideWithValue(
          FakeInspectionRepository(),
        ),
        activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
        vehicleRepositoryProvider.overrideWithValue(FakeVehicleRepository()),
        authRepositoryProvider.overrideWithValue(repository),
        firebaseAvailabilityProvider.overrideWithValue(
          const FirebaseAvailability(),
        ),
      ],
      child: const MyCarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MyCarApp)));
}

void main() {
  test('E-posta boşluk ve harf farklarını temizler, adresi değiştirmez', () {
    expect(
      normalizeAuthEmail('  TEST+car@Example.COM  '),
      'test+car@example.com',
    );
  });
  testWidgets(
    'Saklanan oturum açılışta kullanılır, çıkış yeniden açılışta korunur',
    (tester) async {
      final repository = FakeAuthRepository(
        user: const AppUser(uid: 'saved', email: 'saved@example.com'),
      );
      await start(tester, repository);
      expect(find.text('Garajın seni bekliyor'), findsOneWidget);
      expect(repository.submissions, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await start(tester, repository);
      expect(find.text('Garajın seni bekliyor'), findsOneWidget);
      await repository.signOut();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await start(tester, repository);
      expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    },
  );
  testWidgets('Mevcut e-postayla kayıt hatası gösterilir ve giriş açılmaz', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..failure =
          'Bu e-posta zaten kayıtlı. Giriş yapabilir veya şifreni sıfırlayabilirsin.';
    final container = await start(tester, repository);
    container.read(routerProvider).go('/register');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta'),
      ' TEST@Example.COM ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifre'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifre tekrar'),
      'secret123',
    );
    await tester.ensureVisible(find.text('Kaydol'));
    await tester.tap(find.text('Kaydol'));
    await tester.pumpAndSettle();
    expect(repository.lastEmail, 'test@example.com');
    expect(repository.user, isNull);
    expect(find.textContaining('Bu e-posta zaten kayıtlı'), findsOneWidget);
  });
  testWidgets('Oturum hatası yeniden denenebilir', (tester) async {
    final repository = FakeAuthRepository();
    await start(tester, repository);
    repository.changes.addError(Exception('Bağlantı kesildi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Oturum kontrol edilemedi'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
  });
  testWidgets(
    'Girişsiz özel sayfalar açılmaz; hatalı giriş Türkçe gösterilir',
    (tester) async {
      final repository = FakeAuthRepository()
        ..failure = 'E-posta veya şifre hatalı.';
      final container = await start(tester, repository);
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Tekrar hoş geldin'), findsOneWidget);
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      expect(find.text('E-posta adresini gir.'), findsOneWidget);
      expect(repository.submissions, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        '  test@example.com  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        ' secret ',
      );
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(repository.lastEmail, 'test@example.com');
      expect(repository.lastPassword, ' secret ');
      expect(find.text('Yola hazır mısın?'), findsNothing);
    },
  );
  testWidgets(
    'Kayıt şifre eşleşmesini doğrular; oturum açılır ve çıkışta korunur',
    (tester) async {
      final repository = FakeAuthRepository();
      final container = await start(tester, repository);
      await tester.tap(find.text('Hesabın yok mu? Kaydol'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre tekrar'),
        'wrong',
      );
      await tester.ensureVisible(find.text('Kaydol'));
      await tester.tap(find.text('Kaydol'));
      await tester.pumpAndSettle();
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      expect(repository.submissions, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre tekrar'),
        'secret123',
      );
      await tester.ensureVisible(find.text('Kaydol'));
      await tester.tap(find.text('Kaydol'));
      await tester.pumpAndSettle();
      expect(find.text('Garajın seni bekliyor'), findsOneWidget);
      await tester.tap(find.byTooltip('Ayarlar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Çıkış yap'));
      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(repository.user, isNotNull);
      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkış yap'));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar hoş geldin'), findsOneWidget);
      container.read(routerProvider).go('/summary');
      await tester.pumpAndSettle();
      expect(find.text('Yola hazır mısın?'), findsNothing);
    },
  );
  testWidgets('Parola sıfırlama sonucu ve girişe dönüş', (tester) async {
    final repository = FakeAuthRepository();
    await start(tester, repository);
    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta'),
      'test@example.com',
    );
    await tester.tap(find.text('Sıfırlama bağlantısı gönder'));
    await tester.pumpAndSettle();
    expect(repository.lastEmail, 'test@example.com');
    expect(find.textContaining('kayıtlı bir hesap varsa'), findsOneWidget);
    await tester.ensureVisible(find.text('Giriş ekranına dön'));
    await tester.tap(find.text('Giriş ekranına dön'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kayıtlı bir hesap varsa'), findsNothing);
  });
  testWidgets(
    'Ayarlarda şifre bağlantısı yalnızca onaydan sonra hesaba gönderilir',
    (tester) async {
      final repository = FakeAuthRepository(
        user: const AppUser(uid: 'test', email: 'test@example.com'),
      );
      await start(tester, repository);
      await tester.tap(find.byTooltip('Ayarlar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Şifremi yenile'));
      await tester.tap(find.text('Şifremi yenile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(repository.submissions, 0);
      await tester.tap(find.text('Şifremi yenile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bağlantı gönder'));
      await tester.pumpAndSettle();
      expect(repository.submissions, 1);
      expect(repository.lastEmail, 'test@example.com');
      expect(repository.user, isNotNull);
      expect(
        find.textContaining('Şifre sıfırlama bağlantısı gönderildi.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Bekleyen işlem ikinci kez gönderilemez', (tester) async {
    final repository = FakeAuthRepository()..pending = Completer<void>();
    await start(tester, repository);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifre'),
      'secret123',
    );
    await tester.tap(find.text('Giriş yap'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.submissions, 1);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Garajın seni bekliyor'), findsOneWidget);
  });
}
