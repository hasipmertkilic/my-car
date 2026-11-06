import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_content.dart';
import '../vehicles/widgets/vehicle_scope.dart';
import '../vehicles/widgets/vehicle_picker.dart';
import '../vehicles/models/vehicle.dart';
import '../records/controllers/activity_controller.dart';
import '../records/utils/record_calculations.dart';
import '../parking/services/parking_location.dart';
import '../parking/repositories/parking_repository.dart';
import 'journey_models.dart';
import 'journey_service.dart';
import 'journey_map.dart';
import 'eds_section.dart';

final journeyNavigatorProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      ),
);

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});
  @override
  Widget build(BuildContext context) => VehicleScope(
    builder: (vehicle) =>
        _JourneyPlanner(key: ValueKey(vehicle!.id), vehicle: vehicle),
  );
}

class _JourneyPlanner extends ConsumerStatefulWidget {
  const _JourneyPlanner({super.key, required this.vehicle});
  final Vehicle vehicle;
  @override
  ConsumerState<_JourneyPlanner> createState() => _JourneyPlannerState();
}

class _JourneyPlannerState extends ConsumerState<_JourneyPlanner> {
  final origin = TextEditingController(text: 'Şu anki konumum'),
      destination = TextEditingController(),
      consumption = TextEditingController(),
      price = TextEditingController();
  final form = GlobalKey<FormState>();
  final fees = <String, TextEditingController>{};
  bool current = true,
      avoidTolls = false,
      busy = false,
      seeded = false,
      consumptionEdited = false,
      priceEdited = false;
  bool seededConsumption = false, seededPrice = false;
  JourneyPoint? originPoint, destinationPoint;
  List<JourneyRoute>? routes;
  String? selected, error;
  bool get electric => widget.vehicle.fuelType == 'Elektrik';
  JourneyRoute? get chosen =>
      routes?.where((r) => r.id == selected).firstOrNull;
  @override
  void dispose() {
    for (final c in [origin, destination, consumption, price, ...fees.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void invalidateRoutes() {
    routes = null;
    selected = null;
    error = null;
  }

  double? number(String text, double max) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value != null && value.isFinite && value > 0 && value <= max
        ? value
        : null;
  }

  int? feeFor(String id) {
    final text = fees[id]?.text.trim() ?? '';
    if (text.isEmpty) return null;
    final value = RecordCalculations.scaledNumber(text, 2);
    return value != null && value >= 0 && value <= 100000000 ? value : null;
  }

  JourneyBudget? budget(JourneyRoute route) {
    final use = number(consumption.text, 200), cost = number(price.text, 10000);
    return use == null || cost == null
        ? null
        : JourneyBudget(
            km: route.km,
            consumption: use,
            unitPrice: cost,
            tollKurus: feeFor(route.id),
          );
  }

  void seedFromRecords() {
    final records = ref.watch(activityRecordsProvider(widget.vehicle.id));
    if (seeded || !records.hasValue) return;
    seeded = true;
    final fuel =
        records.requireValue
            .where((r) => r.isFuel && r.fuelType == widget.vehicle.fuelType)
            .toList()
          ..sort(RecordCalculations.compare);
    final average = electric
        ? null
        : RecordSummary(fuel).fuelMetrics.litersPer100Km;
    final lastPrice = electric ? null : fuel.lastOrNull?.pricePerLiter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (!consumptionEdited &&
            consumption.text.isEmpty &&
            average != null &&
            average > 0 &&
            average <= 200) {
          consumption.text = average.toStringAsFixed(2).replaceAll('.', ',');
          seededConsumption = true;
        }
        if (!priceEdited &&
            price.text.isEmpty &&
            lastPrice != null &&
            lastPrice > 0 &&
            lastPrice <= 10000) {
          price.text = lastPrice.toStringAsFixed(2).replaceAll('.', ',');
          seededPrice = true;
        }
      });
    });
  }

  Future<void> pickPoint(bool start) async {
    if (busy) return;
    final value = await Navigator.of(context).push<JourneyPoint>(
      MaterialPageRoute(
        builder: (_) => JourneyPointPicker(
          title: start ? 'Başlangıcı seç' : 'Varışı seç',
          initial: start ? originPoint : destinationPoint,
        ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      invalidateRoutes();
      if (start) {
        current = false;
        originPoint = value;
        origin.text = 'Haritada seçilen başlangıç';
      } else {
        destinationPoint = value;
        destination.text = 'Haritada seçilen varış';
      }
    });
  }

  Future<void> search() async {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      routes = null;
      selected = null;
    });
    try {
      JourneyWaypoint start;
      if (current) {
        final position = await ref.read(parkingLocationProvider).locate();
        if (!mounted) return;
        originPoint = JourneyPoint(position.latitude, position.longitude);
        start = JourneyWaypoint.point(originPoint!);
      } else {
        start = originPoint != null
            ? JourneyWaypoint.point(originPoint!)
            : JourneyWaypoint.address(origin.text);
      }
      final end = destinationPoint != null
          ? JourneyWaypoint.point(destinationPoint!)
          : JourneyWaypoint.address(destination.text);
      final values = await ref
          .read(journeyServiceProvider)
          .plan(start, end, avoidTolls: avoidTolls);
      if (!mounted) return;
      setState(() {
        for (final c in fees.values) {
          c.dispose();
        }
        fees.clear();
        for (final route in values) {
          fees[route.id] = TextEditingController();
        }
        routes = values;
        selected =
            values.where((r) => r.recommended).firstOrNull?.id ??
            values.first.id;
      });
    } on JourneyFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } on ParkingFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Rota hesaplanamadı. Konum ve bağlantını kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> navigate(JourneyRoute route) async {
    try {
      final uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': route.start.coordinateText,
        'destination': route.end.coordinateText,
        'travelmode': 'driving',
        'dir_action': 'navigate',
        if (avoidTolls) 'avoid': 'tolls',
      });
      if (await ref.read(journeyNavigatorProvider)(uri)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Haritalar açılamadı. Tekrar dene.'),
        ),
      );
    }
  }

  String duration(int seconds) {
    final minutes = (seconds / 60).ceil();
    return minutes < 60
        ? '$minutes dk'
        : '${minutes ~/ 60} sa ${minutes % 60} dk';
  }

  @override
  Widget build(BuildContext context) {
    seedFromRecords();
    final t = Theme.of(context);
    final c = t.colorScheme;
    final route = chosen;
    final estimate = route == null ? null : budget(route);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/summary'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Yolculuk planı'),
      ),
      body: PageContent(
        children: [
          const PageHeading(
            'Bugün yolculuk nereye?',
            eyebrow: 'ROTA OLUŞTUR',
            subtitle:
                'Başlangıcı ve varışı seç, yolculuğunun tahmini maliyetini gör.',
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${widget.vehicle.name} • ${widget.vehicle.fuelType}',
                style: t.textTheme.titleSmall,
              ),
              TextButton.icon(
                onPressed: busy ? null : () => showVehiclePicker(context),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Aracı değiştir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Şu anki konumdan başla'),
                      subtitle: const Text(
                        'Konum yalnızca rota aradığında alınır.',
                      ),
                      value: current,
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              current = value;
                              originPoint = null;
                              origin.text = value ? 'Şu anki konumum' : '';
                              invalidateRoutes();
                            }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: origin,
                      enabled: !busy,
                      readOnly: current,
                      decoration: InputDecoration(
                        labelText: 'Başlangıç',
                        hintText: 'Örn. Kadıköy, İstanbul',
                        prefixIcon: const Icon(Icons.trip_origin),
                        suffixIcon: IconButton(
                          tooltip: 'Başlangıcı haritadan seç',
                          onPressed: busy ? null : () => pickPoint(true),
                          icon: const Icon(Icons.map_outlined),
                        ),
                      ),
                      validator: (value) => current || originPoint != null
                          ? null
                          : (value?.trim().length ?? 0) < 3 ||
                                (value?.trim().length ?? 0) > 200
                          ? '3–200 karakter arasında bir başlangıç adresi gir.'
                          : null,
                      onChanged: (_) => setState(() {
                        originPoint = null;
                        invalidateRoutes();
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: destination,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: 'Nereye?',
                        hintText: 'Örn. Çankaya, Ankara',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Varışı haritadan seç',
                          onPressed: busy ? null : () => pickPoint(false),
                          icon: const Icon(Icons.map_outlined),
                        ),
                      ),
                      validator: (value) => destinationPoint != null
                          ? null
                          : (value?.trim().length ?? 0) < 3 ||
                                (value?.trim().length ?? 0) > 200
                          ? '3–200 karakter arasında bir varış adresi gir.'
                          : null,
                      onChanged: (_) => setState(() {
                        destinationPoint = null;
                        invalidateRoutes();
                      }),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Ücretli geçişlerden kaçın'),
                      subtitle: const Text(
                        'Mümkün olduğunca ücretli yolları dışlar.',
                      ),
                      value: avoidTolls,
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              avoidTolls = value ?? false;
                              invalidateRoutes();
                            }),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: busy ? null : search,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.alt_route_rounded),
                      label: Text(
                        busy ? 'Rotalar hesaplanıyor…' : 'Rotaları bul',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionTitle(
            electric ? 'Enerji hesabı' : 'Yakıt hesabı',
            subtitle:
                '${electric ? 'kWh' : 'L'}/100 km × mesafe ÷ 100 × birim fiyat. Değerleri değiştirebilirsin.',
          ),
          TextField(
            controller: consumption,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: electric
                  ? 'Tüketim (kWh/100 km)'
                  : 'Ortalama tüketim (L/100 km)',
              helperText: seededConsumption && !consumptionEdited
                  ? 'Dolu depo kayıtlarından hesaplandı.'
                  : 'Aracının ortalama tüketimini gir.',
              errorText:
                  consumption.text.isNotEmpty &&
                      number(consumption.text, 200) == null
                  ? '0 ile 200 arasında geçerli bir değer gir.'
                  : null,
            ),
            onChanged: (_) => setState(() => consumptionEdited = true),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: price,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: electric
                  ? 'Birim fiyat (TL/kWh)'
                  : 'Litre fiyatı (TL)',
              helperText: seededPrice && !priceEdited
                  ? 'Son yakıt kaydındaki fiyat; güncelliğini kontrol et.'
                  : 'Ödeyeceğin güncel birim fiyatı gir.',
              errorText:
                  price.text.isNotEmpty && number(price.text, 10000) == null
                  ? '0 ile 10.000 arasında geçerli bir fiyat gir.'
                  : null,
            ),
            onChanged: (_) => setState(() => priceEdited = true),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(error!, style: TextStyle(color: c.error)),
            ),
          if (routes != null) ...[
            const SizedBox(height: 28),
            SectionTitle(
              'Rota seçenekleri',
              subtitle:
                  '${routes!.length} sürüş rotası • Canlı trafik hesaba katılmaz.',
            ),
            for (final candidate in routes!) ...[
              Material(
                color: candidate.id == selected
                    ? c.primaryContainer
                    : c.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => selected = candidate.id),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              candidate.id == selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: c.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                candidate.name,
                                style: t.textTheme.titleSmall,
                              ),
                            ),
                            if (candidate.recommended)
                              const Icon(Icons.auto_awesome_outlined, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 18,
                          runSpacing: 6,
                          children: [
                            Text(
                              '${Formatters.decimal(candidate.km)} km',
                              style: t.textTheme.titleMedium,
                            ),
                            Text(
                              duration(candidate.durationSeconds),
                              style: t.textTheme.titleMedium,
                            ),
                            if (budget(candidate) != null)
                              Text(
                                '${Formatters.preciseMoney(budget(candidate)!.fuelKurus / 100)} ${electric ? 'enerji' : 'yakıt'}',
                                style: t.textTheme.labelLarge,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (route != null) ...[
              const SizedBox(height: 14),
              JourneyEdsSection(route: route),
              const SizedBox(height: 20),
              const SectionTitle(
                'Geçiş ücreti',
                subtitle:
                    'Otomatik ücret ve geçiş varlığı sorgulanmıyor. Bilgi yoksa boş bırak; ücretsiz olduğunu biliyorsan 0 gir.',
              ),
              TextField(
                key: ValueKey('fee-${route.id}'),
                controller: fees[route.id],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Seçili rotanın geçiş ücreti (TL)',
                  hintText: 'İsteğe bağlı, kullanıcı girişi',
                  errorText:
                      fees[route.id]!.text.trim().isNotEmpty &&
                          feeFor(route.id) == null
                      ? 'Geçerli bir tutar gir (en fazla 1.000.000 TL).'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'TAHMİNİ YOLCULUK MALİYETİ',
                        style: t.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.3,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (estimate == null)
                        const Text(
                          'Maliyeti görmek için tüketim ve birim fiyatı gir.',
                        )
                      else ...[
                        Text(
                          '${Formatters.preciseMoney((estimate.totalKurus ?? estimate.fuelKurus) / 100)}${estimate.totalKurus == null ? ' + geçiş ücreti' : ''}',
                          style: t.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${electric ? 'Enerji' : 'Yakıt'}: ${Formatters.decimal(estimate.units)} ${electric ? 'kWh' : 'L'} • ${Formatters.preciseMoney(estimate.fuelKurus / 100)}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          estimate.tollKurus == null
                              ? 'Geçiş ücreti bilinmiyor; toplam henüz tamamlanmadı.'
                              : 'Geçiş: ${Formatters.preciseMoney(estimate.tollKurus! / 100)} (kullanıcı girişi)',
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Tek yön tahmini. Gerçek tüketim; trafik, hız, yük ve sürüşe göre değişir.',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => navigate(route),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Google Haritalar’da aç'),
              ),
              const SizedBox(height: 8),
              Text(
                'Google Haritalar rotayı yeniden hesaplayabilir. Başlangıçtan uzaktaysan önce rota önizlemesi açılır.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
