import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/utils/formatters.dart';
import '../models/vehicle.dart';
import 'turkish_license_plate.dart';

const _logoBrands = {
  'bmw',
  'mercedes-benz',
  'audi',
  'volkswagen',
  'toyota',
  'renault',
  'fiat',
  'ford',
  'opel',
  'peugeot',
  'citroen',
  'hyundai',
  'kia',
  'honda',
  'skoda',
  'seat',
  'dacia',
  'nissan',
  'volvo',
  'tesla',
  'togg',
  'suzuki',
  'mazda',
  'mitsubishi',
};

String? _vehicleLogo(String brand) {
  final normalized = brand
      .trim()
      .toLowerCase()
      .replaceAll('š', 's')
      .replaceAll('ë', 'e')
      .replaceAll('\u0307', '')
      .replaceAll('ı', 'i');
  final slug = switch (normalized) {
    'mercedes' || 'mercedes benz' => 'mercedes-benz',
    'vw' => 'volkswagen',
    _ => normalized,
  };
  return _logoBrands.contains(slug) ? 'assets/vehicle_brands/$slug.png' : null;
}

class VehicleOverviewCard extends StatelessWidget {
  const VehicleOverviewCard({
    super.key,
    required this.vehicle,
    required this.onSelect,
  });
  final Vehicle vehicle;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final logo = _vehicleLogo(vehicle.brand);
    final fallback = Icon(
      Icons.directions_car_filled_rounded,
      color: logo == null ? c.surface : c.onSurface,
      size: 24,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: logo == null ? c.onSurface : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: logo == null
                          ? null
                          : Border.all(color: c.outlineVariant),
                    ),
                    child: logo == null
                        ? fallback
                        : Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              logo,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) => fallback,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicle.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        TurkishLicensePlate(plate: vehicle.plate),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Aracı değiştir',
                    child: Icon(
                      Icons.unfold_more_rounded,
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.primaryContainer.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'ARAÇ PROFİLİ',
                        style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Text(
                      '${vehicle.year}',
                      style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 135,
                width: double.infinity,
                child: ExcludeSemantics(
                  child: CustomPaint(painter: VehicleStudioPainter(c)),
                ),
              ),
              Container(
                color: c.surface.withValues(alpha: .6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final km = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Güncel kilometre',
                          style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${Formatters.number(vehicle.currentKm)} km',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.fuelType,
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          vehicle.transmission,
                          style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                    if (box.maxWidth < 260 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                      return Wrap(
                        spacing: 24,
                        runSpacing: 10,
                        children: [km, details],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: km),
                        Container(
                          width: 1,
                          height: 34,
                          color: c.outlineVariant,
                        ),
                        const SizedBox(width: 20),
                        details,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VehicleStudioPainter extends CustomPainter {
  const VehicleStudioPainter(this.colors);
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final light = colors.brightness == Brightness.light;
    final scale = math.min(size.width / 360, size.height / 145);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 145 * scale) / 2,
    );
    canvas.scale(scale);
    final line = Paint()
      ..color = colors.primary.withValues(alpha: .08)
      ..strokeWidth = .8;
    for (var x = 10.0; x < 360; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, 145), line);
    }
    for (var y = 10.0; y < 145; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(360, y), line);
    }
    canvas.drawOval(
      const Rect.fromLTWH(45, 111, 275, 13),
      Paint()..color = colors.primary.withValues(alpha: .09),
    );
    final body = Path()
      ..moveTo(40, 91)
      ..lineTo(48, 73)
      ..quadraticBezierTo(53, 67, 84, 64)
      ..lineTo(119, 37)
      ..quadraticBezierTo(157, 24, 196, 35)
      ..lineTo(238, 62)
      ..lineTo(290, 68)
      ..quadraticBezierTo(313, 73, 316, 88)
      ..lineTo(312, 106)
      ..lineTo(44, 108)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? [Colors.white, const Color(0xFFD1D8E9), const Color(0xFF8B99B2)]
              : [
                  const Color(0xFFB9C6E4),
                  const Color(0xFF7082AA),
                  const Color(0xFF344361),
                ],
        ).createShader(const Rect.fromLTWH(40, 30, 280, 80)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = colors.onSurface.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final glass = Paint()..color = const Color(0xFF243453);
    canvas.drawPath(
      Path()
        ..moveTo(101, 63)
        ..lineTo(126, 41)
        ..quadraticBezierTo(145, 35, 159, 37)
        ..lineTo(166, 63)
        ..close(),
      glass,
    );
    canvas.drawPath(
      Path()
        ..moveTo(166, 37)
        ..quadraticBezierTo(191, 37, 220, 63)
        ..lineTo(173, 63)
        ..close(),
      glass,
    );
    canvas.drawLine(
      const Offset(173, 66),
      const Offset(174, 99),
      Paint()
        ..color = colors.primary.withValues(alpha: .4)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      const Offset(110, 99),
      const Offset(244, 99),
      Paint()
        ..color = light ? Colors.white : const Color(0xFFB6C7E9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    for (final x in [90.0, 269.0]) {
      canvas.drawCircle(
        Offset(x, 105),
        21,
        Paint()..color = const Color(0xFF192033),
      );
      canvas.drawCircle(
        Offset(x, 105),
        13,
        Paint()..color = const Color(0xFF9AA8BE),
      );
      for (var i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5;
        canvas.drawLine(
          Offset(x, 105),
          Offset(x + 10 * math.cos(angle), 105 + 10 * math.sin(angle)),
          Paint()
            ..color = const Color(0xFFDFE6F1)
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(
        Offset(x, 105),
        4,
        Paint()..color = const Color(0xFF3B4B68),
      );
    }
    canvas.drawLine(
      const Offset(293, 76),
      const Offset(307, 79),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(47, 77),
      const Offset(51, 77),
      Paint()
        ..color = const Color(0xFFCC5A64)
        ..strokeWidth = 4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VehicleStudioPainter old) =>
      old.colors != colors;
}
