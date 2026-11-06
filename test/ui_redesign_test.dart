import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/dashboard/screens/dashboard_screen.dart';
import 'package:my_car/features/settings/controllers/theme_controller.dart';
import 'widget_test.dart' show authenticatedApp;

Future<void> snapshot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(boundary);
  await tester.pump();
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('Telefon ve masaüstü gezinme düzeni, açık/koyu görünüm', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final root = Platform.environment['FLUTTER_ROOT'];
      if (root != null) {
        for (final entry in {
          'Roboto': ['roboto-regular.ttf', 'roboto-bold.ttf'],
          'MaterialIcons': ['materialicons-regular.otf'],
        }.entries) {
          final loader = FontLoader(entry.key);
          for (final file in entry.value) {
            loader.addFont(
              File(
                '$root/bin/cache/artifacts/material_fonts/$file',
              ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          }
          await loader.load();
        }
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: authenticatedApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await snapshot(tester, key, 'summary-light');
    await tester.tap(find.byTooltip('Hızlı erişimi aç'));
    await snapshot(tester, key, 'menu-light');
    await tester.tap(find.byTooltip('Hızlı erişimi kapat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kayıtlar'));
    await snapshot(tester, key, 'records-light');
    await tester.tap(find.text('Özet'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await snapshot(tester, key, 'summary-dark');
    container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garaj'));
    await snapshot(tester, key, 'garage-light');
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Özet'));
    await snapshot(tester, key, 'summary-desktop');
    expect(tester.takeException(), isNull);
  });
}
