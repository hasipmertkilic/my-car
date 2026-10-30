import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'expertise_record.dart';

Color expertiseColor(String status) => switch (status) {
  'original' => const Color(0xFF10B981),
  'painted' => const Color(0xFFF59E0B),
  'local_paint' => const Color(0xFF8B5CF6),
  'replaced' => const Color(0xFFEF4444),
  'damaged' => const Color(0xFFF97316),
  _ => const Color(0xFF64748B),
};

// Paths use a 100 x 200 drawing, front at the top, left/right from the driver.
Path _mirror(Path path) => path.transform(
  Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 100, 0, 0, 1]),
);
final _leftWing = Path()
  ..moveTo(30, 15)
  ..quadraticBezierTo(20, 18, 19, 34)
  ..lineTo(18, 65)
  ..lineTo(28, 65)
  ..lineTo(29, 42)
  ..lineTo(36, 30)
  ..close();
final _leftFrontDoor = Path()
  ..moveTo(18, 68)
  ..lineTo(28, 68)
  ..lineTo(31, 100)
  ..lineTo(31, 113)
  ..lineTo(18, 113)
  ..quadraticBezierTo(16, 90, 18, 68)
  ..close();
final _leftRearDoor = Path()
  ..moveTo(18, 116)
  ..lineTo(31, 116)
  ..lineTo(31, 132)
  ..lineTo(27, 149)
  ..lineTo(18, 149)
  ..close();
final _leftRearWing = Path()
  ..moveTo(18, 152)
  ..lineTo(27, 152)
  ..lineTo(31, 166)
  ..lineTo(32, 181)
  ..lineTo(24, 180)
  ..quadraticBezierTo(18, 175, 18, 165)
  ..close();
final _panels = <String, Path>{
  'front_bumper': Path()
    ..moveTo(30, 13)
    ..quadraticBezierTo(50, 4, 70, 13)
    ..lineTo(65, 23)
    ..quadraticBezierTo(50, 18, 35, 23)
    ..close(),
  'hood': Path()
    ..moveTo(36, 26)
    ..quadraticBezierTo(50, 21, 64, 26)
    ..lineTo(70, 43)
    ..lineTo(70, 59)
    ..quadraticBezierTo(50, 53, 30, 59)
    ..lineTo(30, 43)
    ..close(),
  'left_front_wing': _leftWing,
  'right_front_wing': _mirror(_leftWing),
  'left_front_door': _leftFrontDoor,
  'right_front_door': _mirror(_leftFrontDoor),
  'left_rear_door': _leftRearDoor,
  'right_rear_door': _mirror(_leftRearDoor),
  'roof': Path()
    ..moveTo(36, 87)
    ..quadraticBezierTo(50, 82, 64, 87)
    ..lineTo(66, 126)
    ..quadraticBezierTo(50, 132, 34, 126)
    ..close(),
  'left_rear_wing': _leftRearWing,
  'right_rear_wing': _mirror(_leftRearWing),
  'trunk': Path()
    ..moveTo(31, 157)
    ..quadraticBezierTo(50, 164, 69, 157)
    ..lineTo(68, 180)
    ..quadraticBezierTo(50, 186, 32, 180)
    ..close(),
  'rear_bumper': Path()
    ..moveTo(25, 184)
    ..quadraticBezierTo(50, 192, 75, 184)
    ..lineTo(71, 191)
    ..quadraticBezierTo(50, 198, 29, 191)
    ..close(),
};
Path _scaled(Path path, Size size) => path.transform(
  Float64List.fromList([
    size.width / 100,
    0,
    0,
    0,
    0,
    size.height / 200,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]),
);

class ExpertiseDiagram extends StatelessWidget {
  const ExpertiseDiagram({
    super.key,
    required this.parts,
    required this.onSelect,
  });
  final Map<String, String> parts;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: AspectRatio(
        aspectRatio: .55,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CarPainter(parts, Theme.of(context).colorScheme),
              ),
            ),
            for (final panel in _panels.entries)
              Positioned.fill(
                child: ClipPath(
                  clipper: _PanelClipper(panel.value),
                  child: Semantics(
                    button: true,
                    label:
                        '${expertiseParts[panel.key]}: ${expertiseStatuses[parts[panel.key]]}',
                    child: Tooltip(
                      message:
                          '${expertiseParts[panel.key]} • ${expertiseStatuses[parts[panel.key]]}',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(onTap: () => onSelect(panel.key)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PanelClipper extends CustomClipper<Path> {
  const _PanelClipper(this.path);
  final Path path;
  @override
  Path getClip(Size size) => _scaled(path, size);
  @override
  bool shouldReclip(covariant _PanelClipper old) => old.path != path;
}

class _CarPainter extends CustomPainter {
  _CarPainter(Map<String, String> parts, this.colors) : parts = Map.of(parts);
  final Map<String, String> parts;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 200);
    final body = Path()
      ..moveTo(32, 11)
      ..quadraticBezierTo(50, 3, 68, 11)
      ..quadraticBezierTo(80, 15, 81, 35)
      ..lineTo(83, 66)
      ..quadraticBezierTo(86, 100, 82, 132)
      ..lineTo(82, 170)
      ..quadraticBezierTo(82, 189, 69, 195)
      ..quadraticBezierTo(50, 202, 31, 195)
      ..quadraticBezierTo(18, 189, 18, 170)
      ..lineTo(18, 132)
      ..quadraticBezierTo(14, 100, 17, 66)
      ..lineTo(19, 35)
      ..quadraticBezierTo(20, 15, 32, 11)
      ..close();
    canvas.drawShadow(body, Colors.black.withValues(alpha: .4), 4, true);
    // Exposed tires, side mirrors and a continuous silhouette.
    for (final x in [13.0, 78.0]) {
      for (final y in [36.0, 151.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 9, 25),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF101827),
        );
      }
    }
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            colors.surfaceContainerHighest,
            colors.surface,
            colors.surfaceContainerHighest,
          ],
        ).createShader(const Rect.fromLTWH(17, 8, 66, 190)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = colors.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    for (final panel in _panels.entries) {
      final color = expertiseColor(parts[panel.key] ?? 'unknown');
      canvas.drawPath(
        panel.value,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, .18)!,
              color.withValues(alpha: .8),
            ],
          ).createShader(panel.value.getBounds()),
      );
      canvas.drawPath(
        panel.value,
        Paint()
          ..color = colors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65,
      );
    }
    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5F91AF), Color(0xFF172D49), Color(0xFF0B192B)],
      ).createShader(const Rect.fromLTWH(27, 60, 46, 98));
    canvas.drawPath(
      Path()
        ..moveTo(30, 62)
        ..quadraticBezierTo(50, 56, 70, 62)
        ..lineTo(64, 82)
        ..quadraticBezierTo(50, 77, 36, 82)
        ..close(),
      glass,
    );
    canvas.drawPath(
      Path()
        ..moveTo(34, 132)
        ..quadraticBezierTo(50, 137, 66, 132)
        ..lineTo(70, 153)
        ..quadraticBezierTo(50, 161, 30, 153)
        ..close(),
      glass,
    );
    for (final left in [true, false]) {
      final front = Path()
        ..moveTo(29, 71)
        ..lineTo(33, 86)
        ..lineTo(33, 111)
        ..lineTo(26, 111)
        ..close();
      final rear = Path()
        ..moveTo(26, 118)
        ..lineTo(33, 118)
        ..lineTo(33, 130)
        ..lineTo(28, 145)
        ..close();
      canvas.drawPath(left ? front : _mirror(front), glass);
      canvas.drawPath(left ? rear : _mirror(rear), glass);
    }
    // Mirrors, handles, lights and grille make the silhouette recognisable.
    for (final x in [11.0, 81.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 67, 8, 5),
          const Radius.circular(2),
        ),
        Paint()..color = colors.outline,
      );
    }
    final light = Paint()..color = const Color(0xFFFFE9A6);
    for (final x in [23.0, 66.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 22, 11, 4),
          const Radius.circular(1.5),
        ),
        light,
      );
    }
    for (final x in [24.0, 66.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 180, 10, 3),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFFEF4444),
      );
    }
    for (final x in [20.0, 78.0]) {
      for (final y in [103.0, 137.0]) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 2, y),
          Paint()
            ..color = colors.onSurface.withValues(alpha: .75)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(39, 13, 22, 4),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF172033),
    );
    final crease = Paint()
      ..color = Colors.white.withValues(alpha: .28)
      ..strokeWidth = .6;
    canvas.drawLine(const Offset(38, 30), const Offset(34, 50), crease);
    canvas.drawLine(const Offset(62, 30), const Offset(66, 50), crease);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) =>
      old.parts != parts || old.colors != colors;
}
