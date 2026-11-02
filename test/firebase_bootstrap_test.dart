import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/core/services/firebase_bootstrap.dart';
import 'package:my_car/firebase_options.dart';

void main() {
  test(
    'Android mevcut yerel Firebase ayarını kullanır, Dart anahtarı gerektirmez',
    () {
      expect(
        firebaseStartupOptions(web: false, platform: TargetPlatform.android),
        isNull,
      );
      expect(
        firebaseStartupOptions(web: true, platform: TargetPlatform.android),
        same(DefaultFirebaseOptions.web),
      );
    },
  );
  test('Başlangıç hatası anahtar veya ham sunucu mesajını açığa çıkarmaz', () {
    final text = firebaseStartupError(
      FirebaseException(
        plugin: 'core',
        code: 'duplicate-app',
        message: 'sensitive-server-message',
      ),
    );
    expect(text, contains('duplicate-app'));
    expect(text, isNot(contains('sensitive-server-message')));
    expect(
      firebaseStartupError(StateError('private-value')),
      isNot(contains('private-value')),
    );
  });
}
