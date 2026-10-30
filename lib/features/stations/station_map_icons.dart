import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'station_brand.dart';

final stationBrandLogoProvider = FutureProvider.autoDispose
    .family<ui.Image?, String>((ref, asset) async {
      try {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        try {
          final image = (await codec.getNextFrame()).image;
          if (!ref.mounted) {
            image.dispose();
            return null;
          }
          ref.onDispose(image.dispose);
          return image;
        } finally {
          codec.dispose();
        }
      } catch (_) {
        return null;
      }
    });

class StationBubbleIcons {
  const StationBubbleIcons(this.normal, this.selected);
  final BitmapDescriptor normal, selected;
}

final stationBubbleProvider = FutureProvider.autoDispose
    .family<StationBubbleIcons, ({String name, String distance})>((
      ref,
      label,
    ) async {
      final asset = stationBrandAsset(label.name);
      final logo = asset == null
          ? null
          : await ref.watch(stationBrandLogoProvider(asset).future);
      final normal = await drawStationBubble(
        label.name,
        label.distance,
        logo: logo,
      );
      final selected = await drawStationBubble(
        label.name,
        label.distance,
        selected: true,
        logo: logo,
      );
      return StationBubbleIcons(
        BitmapDescriptor.bytes(normal, width: 124, height: 52),
        BitmapDescriptor.bytes(selected, width: 124, height: 52),
      );
    });

// Render compact labels at double resolution for sharp text and logos.
Future<Uint8List> drawStationBubble(
  String name,
  String distance, {
  bool selected = false,
  ui.Image? logo,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(2);
  final body = ui.Path()
    ..addRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(4, 3, 116, 37),
        const ui.Radius.circular(8),
      ),
    );
  final tail = ui.Path()
    ..moveTo(55, 39)
    ..lineTo(62, 48)
    ..lineTo(70, 39)
    ..close();
  final shape = ui.Path.combine(ui.PathOperation.union, body, tail);
  final paint = ui.Paint()..isAntiAlias = true;
  canvas.drawShadow(shape, const ui.Color(0x66000000), 3, false);
  canvas.drawPath(
    shape,
    paint
      ..color = selected
          ? const ui.Color(0xFFFFF7ED)
          : const ui.Color(0xFFFFFFFF),
  );
  canvas.drawPath(
    shape,
    paint
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = selected ? 2 : 1
      ..color = selected
          ? const ui.Color(0xFFF97316)
          : const ui.Color(0xFFCBD5E1),
  );
  paint.style = ui.PaintingStyle.fill;
  if (logo != null) {
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(8, 8, 27, 27),
        const ui.Radius.circular(5),
      ),
      paint..color = const ui.Color(0xFFFFFFFF),
    );
    final ratio = logo.width / logo.height;
    final width = ratio >= 1 ? 23.0 : 23.0 * ratio;
    final height = ratio >= 1 ? 23.0 / ratio : 23.0;
    canvas.drawImageRect(
      logo,
      ui.Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      ui.Rect.fromLTWH(21.5 - width / 2, 21.5 - height / 2, width, height),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  } else {
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(9, 9, 25, 25),
        const ui.Radius.circular(6),
      ),
      paint..color = const ui.Color(0xFFFFEDD5),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(14, 13, 11, 17),
        const ui.Radius.circular(2),
      ),
      paint..color = const ui.Color(0xFFEA580C),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(16, 15, 7, 5),
      paint..color = const ui.Color(0xFFFFEDD5),
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(25, 21)
        ..lineTo(28, 21)
        ..lineTo(28, 28)
        ..quadraticBezierTo(32, 30, 31, 24)
        ..lineTo(30, 17)
        ..lineTo(27, 14),
      paint
        ..color = const ui.Color(0xFFEA580C)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = ui.StrokeCap.round,
    );
  }
  final asset = stationBrandAsset(name);
  final title = switch (asset) {
    'assets/station_brands/shell.png' => 'Shell',
    'assets/station_brands/opet.png' => 'Opet',
    'assets/station_brands/petrol_ofisi.png' => 'Petrol Ofisi',
    'assets/station_brands/bp.png' => 'BP',
    'assets/station_brands/totalenergies.png' => 'TotalEnergies',
    _ => name,
  };
  final paragraph =
      (ui.ParagraphBuilder(
              ui.ParagraphStyle(maxLines: 1, ellipsis: '…', fontSize: 11),
            )
            ..pushStyle(
              ui.TextStyle(
                color: const ui.Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: ui.FontWeight.w700,
              ),
            )
            ..addText(title))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 77));
  canvas.drawParagraph(paragraph, ui.Offset(39, 21.5 - paragraph.height / 2));
  paragraph.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(248, 104);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('İstasyon etiketi oluşturulamadı.');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class StationMapIcons {
  const StationMapIcons(this.normal, this.selected, this.location);
  final BitmapDescriptor normal, selected, location;
}

final stationMapIconsProvider = FutureProvider<StationMapIcons>((ref) async {
  final normal = await _drawIcon();
  final selected = await _drawIcon(selected: true);
  final location = await _drawIcon(location: true);
  return StationMapIcons(
    BitmapDescriptor.bytes(normal, width: 52, height: 52),
    BitmapDescriptor.bytes(selected, width: 62, height: 62),
    BitmapDescriptor.bytes(location, width: 36, height: 36),
  );
});

Future<Uint8List> _drawIcon({
  bool selected = false,
  bool location = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const center = ui.Offset(60, 60);
  final paint = ui.Paint()..isAntiAlias = true;
  if (location) {
    canvas.drawCircle(center, 48, paint..color = const ui.Color(0x332563EB));
    canvas.drawCircle(center, 29, paint..color = const ui.Color(0xFFFFFFFF));
    canvas.drawCircle(center, 21, paint..color = const ui.Color(0xFF2563EB));
    canvas.drawCircle(
      const ui.Offset(54, 53),
      6,
      paint..color = const ui.Color(0xFF93C5FD),
    );
  } else {
    final body = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(13, 10, 94, 94),
      const ui.Radius.circular(30),
    );
    canvas.drawShadow(
      ui.Path()..addRRect(body),
      const ui.Color(0xAA000000),
      6,
      false,
    );
    if (selected) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          const ui.Rect.fromLTWH(5, 2, 110, 110),
          const ui.Radius.circular(37),
        ),
        paint..color = const ui.Color(0x66F97316),
      );
    }
    canvas.drawRRect(
      body,
      paint
        ..shader = ui.Gradient.linear(
          const ui.Offset(20, 10),
          const ui.Offset(100, 104),
          selected
              ? [const ui.Color(0xFFFFBA55), const ui.Color(0xFFF97316)]
              : [const ui.Color(0xFF334155), const ui.Color(0xFF0F172A)],
        ),
    );
    paint.shader = null;
    canvas.drawRRect(
      body,
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = selected
            ? const ui.Color(0xFFFFEDD5)
            : const ui.Color(0xFFF97316),
    );
    paint.style = ui.PaintingStyle.fill;
    final foreground = selected
        ? const ui.Color(0xFF0F172A)
        : const ui.Color(0xFFFFA34F);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(34, 30, 35, 52),
        const ui.Radius.circular(5),
      ),
      paint..color = foreground,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(40, 37, 23, 15),
        const ui.Radius.circular(3),
      ),
      paint
        ..color = selected
            ? const ui.Color(0xFFFFC876)
            : const ui.Color(0xFF172238),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(29, 80, 45, 6),
        const ui.Radius.circular(3),
      ),
      paint..color = foreground,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(69, 57)
        ..lineTo(75, 57)
        ..lineTo(75, 73)
        ..quadraticBezierTo(75, 83, 83, 79)
        ..quadraticBezierTo(87, 77, 85, 69)
        ..lineTo(82, 48)
        ..lineTo(74, 38),
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = ui.StrokeCap.round
        ..color = foreground,
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(120, 120);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('İstasyon simgesi oluşturulamadı.');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}
