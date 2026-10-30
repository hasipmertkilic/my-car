import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/expertise/expertise_record.dart';
import 'package:my_car/features/expertise/expertise_repository.dart';
import 'package:my_car/features/expertise/expertise_diagram.dart';
import 'widget_test.dart' show authenticatedApp;

class FakeExpertise implements ExpertiseRepository {
  final records = <String, ExpertiseRecord>{};
  final changes = StreamController<void>.broadcast(sync: true);
  bool fail = false;
  @override
  Stream<ExpertiseRecord?> watch(String id) => Stream.multi((c) {
    c.add(records[id]);
    final sub = changes.stream.listen((_) {
      c.add(records[id]);
    });
    c.onCancel = sub.cancel;
  });
  @override
  Future<void> save(String id, ExpertiseRecord entry) async {
    if (fail) throw const ExpertiseFailure('Kayıt başarısız');
    records[id] = entry;
    changes.add(null);
  }

  @override
  Future<String> upload(String id, Uint8List bytes) async => 'report';
  @override
  Future<Uint8List> readPdf(String id, String report) async =>
      Uint8List.fromList('%PDF-1.7'.codeUnits);
  @override
  Future<void> removePdf(String id, String report) async {}
}

void main() {
  test('Parçalar belirtilmedi başlar, durumlar ve PDF doğrulanır', () {
    final entry = ExpertiseRecord(
      parts: {'hood': 'replaced'},
      notes: 'Kontrol',
    );
    expect(entry.parts.length, 13);
    expect(entry.parts['roof'], 'unknown');
    expect(entry.valid, isTrue);
    expect(ExpertiseRecord.fromMap(entry.toMap()).parts['hood'], 'replaced');
    expect(ExpertiseRecord(parts: {'hood': 'invalid'}).valid, isFalse);
    expect(
      ExpertiseRecord(reportId: '../other', reportName: 'x.pdf').valid,
      isFalse,
    );
    expect(isExpertisePdf('%PDF-1.7'.codeUnits), isTrue);
    expect(isExpertisePdf('photo'.codeUnits), isFalse);
  });
  testWidgets('Şemadan parça seçilir, kaydedilir ve hatada seçim korunur', (
    tester,
  ) async {
    final repo = FakeExpertise();
    addTearDown(repo.changes.close);
    await tester.pumpWidget(authenticatedApp(expertise: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hızlı erişimi aç'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0,-250)); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Araç ekspertizi'));
    await tester.tap(find.text('Araç ekspertizi'));
    await tester.pumpAndSettle();
    final diagram = tester.widget<ExpertiseDiagram>(
      find.byType(ExpertiseDiagram),
    );
    diagram.onSelect('hood');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Değişen'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Değişiklikleri kaydet'));
    await tester.tap(find.text('Değişiklikleri kaydet'));
    await tester.pumpAndSettle();
    expect(repo.records['bmw']!.parts['hood'], 'replaced');
    expect(repo.records['clio'], isNull);
    repo.fail = true;
    tester
        .widget<ExpertiseDiagram>(find.byType(ExpertiseDiagram))
        .onSelect('roof');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Boyalı'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Değişiklikleri kaydet'));
    await tester.tap(find.text('Değişiklikleri kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Kayıt başarısız'), findsOneWidget);
    expect(
      tester
          .widget<ExpertiseDiagram>(find.byType(ExpertiseDiagram))
          .parts['roof'],
      'painted',
    );
  });
}

