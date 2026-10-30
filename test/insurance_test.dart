import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_car/features/insurance/models/insurance_policy.dart';
import 'package:my_car/features/insurance/repositories/policy_repository.dart';
import 'package:my_car/features/insurance/screens/policy_form_screen.dart';
import 'package:my_car/features/insurance/services/policy_document_importer.dart';
import 'package:my_car/features/insurance/services/policy_document_parser.dart';

class FakeDocumentImporter implements PolicyDocumentImporter {
  PolicyDocumentFields? result;
  String? failure;
  PolicyDocumentSource? source;
  @override
  Future<PolicyDocumentFields?> read(PolicyDocumentSource value) async {
    source = value;
    if (failure != null) throw DocumentReadFailure(failure!);
    return result;
  }
}

InsurancePolicy policy({
  String id = 'p1',
  String kind = 'traffic',
  int? step = 8,
  String level = '',
  DateTime? start,
  DateTime? end,
}) => InsurancePolicy(
  id: id,
  kind: kind,
  company: 'Örnek Sigorta',
  number: 'P-123',
  startDate: start ?? DateTime(2026, 10, 1),
  endDate: end ?? DateTime(2027, 10, 1),
  premiumKurus: 1250050,
  step: step,
  level: level,
);

class FakePolicies implements PolicyRepository {
  final values = <String, List<InsurancePolicy>>{};
  InsurancePolicy? saved;
  String? vehicle, failure;
  Completer<void>? pending;
  int submissions = 0;
  @override
  Stream<List<InsurancePolicy>> watch(String id) =>
      Stream.value(values[id] ?? []);
  @override
  Future<void> save(String id, InsurancePolicy policy) async {
    submissions++;
    if (pending != null) {
      await pending!.future;
    }
    if (failure != null) {
      throw PolicyFailure(failure!);
    }
    saved = policy;
    vehicle = id;
  }

  @override
  Future<void> archive(
    String id,
    String policyId, {
    bool archived = true,
  }) async {}
}

Future<void> start(
  WidgetTester tester,
  FakePolicies repository, {
  InsurancePolicy? initial,
  PolicyDocumentImporter? importer,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            PolicyForm(vehicleId: 'bmw', name: 'BMW 320i', initial: initial),
      ),
      GoRoute(
        path: '/vehicles/bmw/policies',
        builder: (_, _) => const Scaffold(body: Text('Poliçe listesi')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        policyRepositoryProvider.overrideWithValue(repository),
        if (importer != null)
          policyDocumentImporterProvider.overrideWithValue(importer),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr'));
  testWidgets(
    'Belge önce incelenir, onaylanmayan şirket korunur ve otomatik kayıt yapılmaz',
    (tester) async {
      final repo = FakePolicies();
      final importer = FakeDocumentImporter()
        ..result = const PolicyDocumentFields(
          company: 'Yeni Sigorta',
          number: 'K-9911',
          kind: 'casco',
          level: 'Tam Kasko',
          premiumKurus: 2500050,
        );
      await start(tester, repo, initial: policy(), importer: importer);
      await tester.tap(find.text('PDF / fotoğraf seç'));
      await tester.pumpAndSettle();
      expect(find.text('Belgeden okunan bilgiler'), findsOneWidget);
      expect(repo.submissions, 0);
      await tester.tap(find.text('Sigorta şirketi: Yeni Sigorta'));
      await tester.tap(find.text('Seçilenleri forma doldur'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Örnek Sigorta'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'K-9911'), findsOneWidget);
      expect(find.text('Tam Kasko'), findsOneWidget);
      expect(repo.submissions, 0);
      await tester.ensureVisible(find.text('Poliçeyi kaydet'));
      await tester.tap(find.text('Poliçeyi kaydet'));
      await tester.pumpAndSettle();
      expect(repo.saved!.kind, 'casco');
      expect(repo.saved!.level, 'Tam Kasko');
      expect(repo.saved!.premiumKurus, 2500050);
      expect(repo.saved!.company, 'Örnek Sigorta');
      expect(repo.saved!.step, isNull);
    },
  );
  testWidgets('Kamera iptali ve okuma hatası mevcut formu değiştirmez', (
    tester,
  ) async {
    final repo = FakePolicies();
    final importer = FakeDocumentImporter();
    await start(tester, repo, initial: policy(), importer: importer);
    await tester.tap(find.text('Fotoğraf çek'));
    await tester.pumpAndSettle();
    expect(importer.source, PolicyDocumentSource.camera);
    expect(find.text('Belgeden okunan bilgiler'), findsNothing);
    importer.failure = 'Fotoğraf okunamadı';
    await tester.tap(find.text('PDF / fotoğraf seç'));
    await tester.pumpAndSettle();
    expect(find.text('Fotoğraf okunamadı'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Örnek Sigorta'), findsOneWidget);
    expect(repo.submissions, 0);
  });
  test(
    'Poliçe türü ve basamak/kapsam tutarlı olmalı; tarih dönüşümü korunur',
    () {
      expect(policy().valid, isTrue);
      expect(policy(step: 0).valid, isTrue);
      expect(policy(step: 9).valid, isFalse);
      expect(
        policy(kind: 'casco', step: null, level: 'Tam Kasko').valid,
        isTrue,
      );
      expect(policy(kind: 'casco', step: 4, level: 'Tam Kasko').valid, isFalse);
      final restored = InsurancePolicy.fromMap('p1', policy().toMap());
      expect(restored.startDate, DateTime(2026, 10, 1));
      expect(restored.premiumKurus, 1250050);
    },
  );
  test(
    'Özet yenilenmiş poliçeyi seçer; bugünün bitişi ve gelecekte başlangıç ayrılır',
    () {
      final now = DateTime(2026, 10, 19, 23, 59);
      final expired = policy(
        id: 'old',
        start: DateTime(2025),
        end: DateTime(2026, 10, 18),
      );
      final renewed = policy(
        id: 'new',
        start: DateTime(2026, 10, 18),
        end: DateTime(2027, 10, 18),
      );
      expect(relevantPolicy([expired, renewed], 'traffic', now)!.id, 'new');
      expect(
        policy(end: DateTime(2026, 10, 19)).status(now),
        'Bugün sona eriyor',
      );
      expect(expired.status(now), 'Süresi 1 gün önce doldu');
      expect(
        policy(start: DateTime(2026, 10, 20)).status(now),
        '1 gün sonra başlayacak',
      );
    },
  );
  testWidgets(
    'Poliçe formu zorunlu alanları denetler ve kuruş hassasiyetiyle doğru araca kaydeder',
    (tester) async {
      final repo = FakePolicies();
      await start(tester, repo);
      await tester.ensureVisible(find.text('Poliçeyi kaydet'));
      await tester.tap(find.text('Poliçeyi kaydet'));
      await tester.pumpAndSettle();
      expect(repo.submissions, 0);
      expect(find.text('Sigorta şirketi bilgisini gir.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sigorta şirketi'),
        ' Örnek Sigorta ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Poliçe numarası'),
        ' P-123 ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Poliçe tutarı (₺)'),
        '12500,50',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Poliçeyi kaydet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poliçeyi kaydet'));
      await tester.pumpAndSettle();
      expect(repo.vehicle, 'bmw');
      expect(repo.saved!.company, 'Örnek Sigorta');
      expect(repo.saved!.premiumKurus, 1250050);
      expect(find.text('Poliçe listesi'), findsOneWidget);
    },
  );
  testWidgets(
    'Düzenleme kaydı korur; hata başarıya yönlendirmez; beklerken ikinci kez gönderilmez',
    (tester) async {
      final repo = FakePolicies()..failure = 'Kaydedilemedi';
      await start(
        tester,
        repo,
        initial: policy(
          kind: 'casco',
          step: null,
          level: 'Genişletilmiş Kasko',
        ),
      );
      await tester.ensureVisible(find.text('Poliçeyi kaydet'));
      await tester.tap(find.text('Poliçeyi kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Kaydedilemedi'), findsOneWidget);
      expect(find.text('Poliçe listesi'), findsNothing);
      repo.failure = null;
      repo.pending = Completer<void>();
      await tester.tap(find.text('Poliçeyi kaydet'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(repo.saved!.id, 'p1');
      expect(repo.saved!.level, 'Genişletilmiş Kasko');
      expect(repo.saved!.step, isNull);
    },
  );
}
