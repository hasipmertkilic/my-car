import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/formatters.dart';
import 'eds_data.dart';
import 'eds_alerts.dart';
import 'journey_map.dart';
import 'journey_models.dart';

final edsCameraIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..color = const Color(0xFFF59E0B);
  canvas.drawCircle(const Offset(40, 40), 37, Paint()..color = Colors.white);
  canvas.drawCircle(const Offset(40, 40), 33, paint);
  paint.color = const Color(0xFF0F172A);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 27, 44, 30),
      const Radius.circular(6),
    ),
    paint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(27, 21, 18, 11),
      const Radius.circular(3),
    ),
    paint,
  );
  canvas.drawCircle(const Offset(40, 42), 10, Paint()..color = Colors.white);
  canvas.drawCircle(const Offset(40, 42), 6, paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(80, 80);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (bytes == null) throw StateError('camera-icon');
  return BitmapDescriptor.bytes(
    bytes.buffer.asUint8List(),
    width: 36,
    height: 36,
  );
});

class JourneyEdsSection extends ConsumerStatefulWidget {
  const JourneyEdsSection({super.key, required this.route});
  final JourneyRoute route;
  @override
  ConsumerState<JourneyEdsSection> createState() => _JourneyEdsSectionState();
}

class _JourneyEdsSectionState extends ConsumerState<JourneyEdsSection> {
  bool enabled = true;
  List<RouteEdsPoint>? matches;
  EdsDataset? previous;
  String? previousPolyline;
  void details(RouteEdsPoint match, EdsDataset dataset) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFFF59E0B),
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'EDS noktası',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(match.point.name),
              const SizedBox(height: 12),
              Text(
                'Rota başlangıcından yaklaşık ${Formatters.decimal(match.routeKm)} km ileride.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Denetim türü ve hız sınırı kaynakta ayrıca doğrulanmadı. Nokta farklı bir yol veya yön için olabilir; yol levhalarını esas al.',
              ),
              const SizedBox(height: 12),
              Text(
                'Kaynak: EGM • Alınma: ${Formatters.date(dataset.retrievedAt)}\nKaynağın son güncelleme tarihi belirtilmiyor.',
              ),
              TextButton.icon(
                onPressed: openSource,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Resmi EDS haritasını aç'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openSource() async {
    try {
      if (await launchUrl(
        Uri.parse(edsSourceUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resmi harita açılamadı. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(edsDatasetProvider);
    final dataset = data.asData?.value;
    if (dataset != previous || previousPolyline != widget.route.polyline) {
      previous = dataset;
      previousPolyline = widget.route.polyline;
      matches = dataset == null
          ? null
          : edsNearRoute(widget.route.points, dataset.points);
    }
    final found = matches ?? const <RouteEdsPoint>[];
    final icon = enabled
        ? ref.watch(edsCameraIconProvider).asData?.value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyRouteMap(
          route: widget.route,
          eds: enabled ? found : const [],
          edsIcon: icon,
          onEdsTap: dataset == null ? null : (match) => details(match, dataset),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Rota yakınındaki EDS’ler'),
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                ),
                if (data.isLoading) const LinearProgressIndicator(),
                if (data.hasError) ...[
                  const Text(
                    'EDS verisi yüklenemedi; bu, rotada denetim olmadığı anlamına gelmez.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(edsDatasetProvider),
                    child: const Text('Tekrar dene'),
                  ),
                ],
                if (dataset != null) ...[
                  Text(
                    enabled
                        ? (found.isEmpty
                              ? 'Bu veri setinde rota yakınında eşleşme bulunamadı.'
                              : '${found.length} EDS noktası rota yakınında.')
                        : 'EDS işaretleri gizlendi.',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Yaklaşık 150 m yakınlığa göre eşleştirilir; aynı yol/yön olduğu kesin değildir. Tüm denetimleri kapsamaz. Her zaman yolun hız sınırına uy.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'EGM • Veri alınma: ${Formatters.date(dataset.retrievedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (dataset.stale(DateTime.now()))
                    const Text(
                      'Bu veri 30 günden eski; güncel durumu resmi haritadan kontrol et.',
                    ),
                  if (enabled && found.isNotEmpty)
                    EdsAlerts(
                      key: ValueKey(widget.route.polyline),
                      route: widget.route.points,
                      points: found,
                    ),
                  if (enabled && found.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Rota sırasıyla noktalar'),
                      children: [
                        for (final match in found)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.camera_alt_outlined),
                            title: Text(match.point.name),
                            subtitle: Text(
                              'Başlangıçtan ≈ ${Formatters.decimal(match.routeKm)} km',
                            ),
                            onTap: () => details(match, dataset),
                          ),
                      ],
                    ),
                ],
                TextButton.icon(
                  onPressed: openSource,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('EGM haritası ve ortalama hız bölgeleri'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
