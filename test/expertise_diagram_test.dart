import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/expertise/expertise_diagram.dart';
import 'package:my_car/features/expertise/expertise_record.dart';

void main() {
  testWidgets('Araç şeması görsel önizlemesi ve dokunma alanı', (tester) async {
    final key = GlobalKey();
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: ExpertiseDiagram(
                parts: ExpertiseRecord(
                  parts: {'hood': 'painted', 'left_front_door': 'replaced'},
                ).parts,
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(ExpertiseDiagram));
    await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * .21));
    expect(selected, 'hood');
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
    final data = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
    await tester.runAsync(() async {
      await File(
        'build/expertise-preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    });
    image.dispose();
  });
}


