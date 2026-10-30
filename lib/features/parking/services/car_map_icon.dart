import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

final carMapImageProvider = FutureProvider<Uint8List>(
  (ref) => createCarMapIcon(),
);

/// A crisp, top-down sports car badge shared by the parking maps.
Future<Uint8List> createCarMapIcon() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(3);
  final center = const ui.Offset(48, 48);
  final badge = ui.Path()..addOval(const ui.Rect.fromLTWH(5, 5, 86, 86));
  canvas.drawShadow(badge, const ui.Color(0x99000000), 5, true);
  canvas.drawCircle(center, 43, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  canvas.drawCircle(
    center,
    40,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(12, 12),
        const ui.Offset(82, 86),
        [const ui.Color(0xFFFFB347), const ui.Color(0xFFF97316)],
      ),
  );
  canvas.drawCircle(
    center,
    35.5,
    ui.Paint()..color = const ui.Color(0xFF0F172A),
  );
  void rounded(
    double l,
    double t,
    double r,
    double b,
    double radius,
    int color,
  ) {
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTRB(l, t, r, b),
        ui.Radius.circular(radius),
      ),
      ui.Paint()..color = ui.Color(color),
    );
  }

  // Wheels and mirrors remain distinct at phone marker sizes.
  for (final x in [29.0, 61.0]) {
    rounded(x, 27, x + 6, 40, 2, 0xFF020617);
    rounded(x, 59, x + 6, 72, 2, 0xFF020617);
  }
  rounded(25, 40, 34, 45, 3, 0xFFF97316);
  rounded(62, 40, 71, 45, 3, 0xFFF97316);
  final body = ui.Path()
    ..moveTo(37, 18)
    ..quadraticBezierTo(48, 14, 59, 18)
    ..quadraticBezierTo(65, 22, 65, 35)
    ..lineTo(65, 69)
    ..quadraticBezierTo(64, 79, 56, 80)
    ..lineTo(40, 80)
    ..quadraticBezierTo(32, 79, 31, 69)
    ..lineTo(31, 35)
    ..quadraticBezierTo(31, 22, 37, 18)
    ..close();
  canvas.drawPath(
    body,
    ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(31, 20),
        const ui.Offset(65, 75),
        [const ui.Color(0xFFFFFFFF), const ui.Color(0xFFCBD5E1)],
      ),
  );
  // Panoramic roof and angled windscreen give the car its silhouette.
  canvas.drawPath(
    ui.Path()
      ..moveTo(36, 34)
      ..quadraticBezierTo(48, 30, 60, 34)
      ..lineTo(57, 44)
      ..lineTo(39, 44)
      ..close(),
    ui.Paint()..color = const ui.Color(0xFF334155),
  );
  rounded(39, 46, 57, 61, 4, 0xFF17263B);
  canvas.drawPath(
    ui.Path()
      ..moveTo(39, 63)
      ..lineTo(57, 63)
      ..lineTo(60, 70)
      ..quadraticBezierTo(48, 73, 36, 70)
      ..close(),
    ui.Paint()..color = const ui.Color(0xFF334155),
  );
  rounded(45.5, 19, 50.5, 30, 2, 0xFFF97316);
  rounded(34, 24, 39, 29, 2, 0xFFFFE6B2);
  rounded(57, 24, 62, 29, 2, 0xFFFFE6B2);
  rounded(34, 74, 41, 77, 1, 0xFFEF4444);
  rounded(55, 74, 62, 77, 1, 0xFFEF4444);
  final picture = recorder.endRecording();
  final image = await picture.toImage(288, 288);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Araç simgesi oluşturulamadı.');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}
