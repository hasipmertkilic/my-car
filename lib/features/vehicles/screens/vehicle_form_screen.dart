import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../controllers/vehicle_controller.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';
import '../data/vehicle_catalog.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});
  final Vehicle? vehicle;
  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController year, plate, km, engine;
  String? brand, series, model;
  String? legacyBrand, legacyModel;
  late String fuel, transmission;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    brand = vehicle?.brand;
    model = vehicle?.model;
    series = catalogSeries(brand, model);
    if (brand != null && !vehicleCatalog.containsKey(brand)) {
      legacyBrand = brand;
    }
    if (model != null && series == null) {
      legacyModel = model;
      series = 'Mevcut kayıt';
    }
    year = TextEditingController(text: vehicle?.year.toString());
    plate = TextEditingController(text: vehicle?.plate);
    km = TextEditingController(text: vehicle?.currentKm.toString());
    engine = TextEditingController(text: vehicle?.engineCc.toString());
    fuel = vehicle?.fuelType ?? 'Benzin';
    transmission = vehicle?.transmission ?? 'Otomatik';
  }

  @override
  void dispose() {
    for (final controller in [year, plate, km, engine]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? requiredText(String? value) => value == null || value.trim().isEmpty
      ? 'Bu alanı doldur.'
      : value.trim().length > 80
      ? 'En fazla 80 karakter gir.'
      : null;
  String? integer(String? value, int min, int max) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < min || number > max
        ? '$min–$max arasında tam sayı gir.'
        : null;
  }

  Future<void> save() async {
    if (busy || !formKey.currentState!.validate()) return;
    final repository = ref.read(vehicleRepositoryProvider);
    if (repository == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.save(
        Vehicle(
          id: widget.vehicle?.id ?? '',
          brand: brand!,
          model: model!,
          year: int.parse(year.text.trim()),
          plate: plate.text.trim().toUpperCase(),
          fuelType: fuel,
          transmission: transmission,
          currentKm: int.parse(km.text.trim()),
          engineCc: int.parse(engine.text.trim()),
        ),
      );
      if (mounted) context.go('/garage');
    } on VehicleFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Araç kaydedilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator: validator ?? requiredText,
    ),
  );
  Widget picker(
    String label,
    String? value,
    List<String> options,
    void Function(String?) onChanged, {
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$brand:$series:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text(
        enabled
            ? '$label seç'
            : brand == null
            ? 'Önce marka seç'
            : 'Önce seri seç',
      ),
      items: options
          .toSet()
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      validator: (value) =>
          value == null || value.isEmpty ? '$label seç.' : null,
      onChanged: busy || !enabled ? null : onChanged,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Araç ekle' : 'Aracı düzenle'),
        leading: IconButton(
          tooltip: 'Garaja dön',
          onPressed: busy ? null : () => context.go('/garage'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: PageContent(
        children: [
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Araç bilgilerin yalnızca kendi hesabına kaydedilir.',
                ),
                const SizedBox(height: 20),
                picker(
                  'Marka',
                  brand,
                  [...vehicleCatalog.keys, ?legacyBrand],
                  (value) => setState(() {
                    brand = value;
                    series = null;
                    model = null;
                    if (vehicleCatalog[value]?.length == 1) {
                      series = vehicleCatalog[value]!.keys.first;
                    }
                    if (value == legacyBrand && legacyModel != null) {
                      series = 'Mevcut kayıt';
                      model = legacyModel;
                    }
                  }),
                ),
                if (brand != null &&
                    ((vehicleCatalog[brand]?.length ?? 0) > 1 ||
                        legacyModel != null && brand == widget.vehicle?.brand))
                  picker(
                    'Seri',
                    series,
                    [
                      ...?vehicleCatalog[brand]?.keys,
                      if (legacyModel != null && brand == widget.vehicle?.brand)
                        'Mevcut kayıt',
                    ],
                    (value) => setState(() {
                      series = value;
                      model = value == 'Mevcut kayıt' ? legacyModel : null;
                    }),
                  ),
                picker(
                  'Model',
                  model,
                  [
                    ...?vehicleCatalog[brand]?[series],
                    if (series == 'Mevcut kayıt' && legacyModel != null)
                      legacyModel!,
                  ],
                  (value) => setState(() => model = value),
                  enabled: brand != null && series != null,
                ),
                field(
                  'Model yılı',
                  year,
                  numeric: true,
                  validator: (value) =>
                      integer(value, 1900, DateTime.now().year + 1),
                ),
                field(
                  'Plaka',
                  plate,
                  validator: (value) =>
                      value == null ||
                          value.trim().length < 3 ||
                          value.trim().length > 20
                      ? '3–20 karakter arasında plaka gir.'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: fuel,
                  decoration: const InputDecoration(labelText: 'Yakıt tipi'),
                  items: ['Benzin', 'Dizel', 'LPG', 'Hibrit', 'Elektrik']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => setState(() => fuel = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: transmission,
                  decoration: const InputDecoration(labelText: 'Vites tipi'),
                  items: ['Otomatik', 'Manuel', 'Yarı otomatik']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => setState(() => transmission = value!),
                ),
                const SizedBox(height: 16),
                field(
                  'Motor hacmi (cc)',
                  engine,
                  numeric: true,
                  validator: (value) => integer(value, 0, 20000),
                ),
                field(
                  'Güncel kilometre',
                  km,
                  numeric: true,
                  validator: (value) => integer(value, 0, 10000000),
                ),
                const Text(
                  'Elektrikli araçlarda motor hacmine 0 gir. Fotoğraf yükleme belge ve dosya aşamasında eklenecek.',
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aracı kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
