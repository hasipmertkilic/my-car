import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../../vehicles/models/vehicle.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../controllers/activity_controller.dart';
import '../models/activity_record.dart';
import '../repositories/activity_repository.dart';
import '../utils/record_calculations.dart';
import '../widgets/activity_scope.dart';
import '../services/fuel_receipt_importer.dart';

class ActivityFormRoute extends ConsumerWidget {
  const ActivityFormRoute({
    super.key,
    required this.vehicleId,
    required this.kind,
    this.recordId,
  });
  final String vehicleId, kind;
  final String? recordId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => VehicleScope(
    allowEmpty: true,
    builder: (_) {
      final vehicle = ref
          .watch(vehiclesProvider)
          .asData!
          .value
          .where((v) => v.id == vehicleId)
          .firstOrNull;
      if (vehicle == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Araç bulunamadı')),
          body: const Center(child: Text('Garajına dönüp bir araç seç.')),
        );
      }
      if (recordId == null) {
        return ActivityFormScreen(vehicle: vehicle, kind: kind);
      }
      return ActivityScope(
        vehicleId: vehicleId,
        builder: (records) {
          final record = records.where((r) => r.id == recordId).firstOrNull;
          if (record == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Kayıt bulunamadı')),
              body: const Center(child: Text('Bu kayıt kaldırılmış olabilir.')),
            );
          }
          return ActivityFormScreen(
            key: ValueKey(record.id),
            vehicle: vehicle,
            kind: record.kind,
            record: record,
          );
        },
      );
    },
  );
}

class ActivityFormScreen extends ConsumerStatefulWidget {
  const ActivityFormScreen({
    super.key,
    required this.vehicle,
    required this.kind,
    this.record,
  });
  final Vehicle vehicle;
  final String kind;
  final ActivityRecord? record;
  @override
  ConsumerState<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController km, amount, liters, notes;
  late DateTime date;
  late String category, fuel;
  late bool fullTank;
  bool busy = false;
  bool readingReceipt = false, reviewingReceipt = false;
  String? receiptMessage;
  String? error;
  bool get isFuel => widget.kind == 'fuel';
  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final now = DateTime.now();
    date = record?.date ?? DateTime(now.year, now.month, now.day);
    km = TextEditingController(
      text: (record?.odometerKm ?? widget.vehicle.currentKm).toString(),
    );
    amount = TextEditingController(
      text: record?.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    liters = TextEditingController(
      text: record?.liters.toString().replaceAll('.', ','),
    );
    notes = TextEditingController(text: record?.notes);
    category = record?.category ?? (isFuel ? 'Yakıt' : 'Diğer');
    fuel =
        record?.fuelType ??
        (widget.vehicle.fuelType == 'Elektrik'
            ? 'Benzin'
            : widget.vehicle.fuelType);
    fullTank = record?.fullTank ?? false;
  }

  @override
  void dispose() {
    for (final controller in [km, amount, liters, notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final repository = ref.read(activityRepositoryProvider);
    if (repository == null) {
      setState(() => error = 'Oturumun kapandı. Yeniden giriş yap.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.save(
        widget.vehicle.id,
        ActivityRecord(
          id: widget.record?.id ?? '',
          kind: widget.kind,
          date: date,
          odometerKm: int.parse(km.text.trim()),
          amountKurus: RecordCalculations.scaledNumber(amount.text, 2)!,
          category: isFuel ? 'Yakıt' : category,
          litersMilli: isFuel
              ? RecordCalculations.scaledNumber(liters.text, 3)!
              : 0,
          fullTank: isFuel && fullTank,
          fuelType: isFuel ? fuel : '',
          notes: notes.text.trim(),
        ),
      );
      if (mounted) context.go('/records');
    } on RecordFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) setState(() => error = 'İşlem kaydedilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> readReceipt(FuelReceiptSource source) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      readingReceipt = true;
      receiptMessage = null;
    });
    try {
      final fields = await ref.read(fuelReceiptImporterProvider).read(source);
      if (!mounted || fields == null) return;
      if (fields.isEmpty) {
        setState(
          () => receiptMessage =
              'Litre ve toplam tutar güvenle okunamadı. Fişin tamamı net görünecek şekilde tekrar çekebilir veya elle girebilirsin.',
        );
        return;
      }
      setState(() {
        readingReceipt = false;
        reviewingReceipt = true;
      });
      var useLiters = fields.litersMilli != null,
          useAmount = fields.amountKurus != null;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Fişten okunan bilgiler'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Fişle karşılaştır. Seçtiğin bilgiler formdaki mevcut değerlerin yerine geçecek.',
                  ),
                  if (fields.amountKurus == null)
                    const Text(
                      'Toplam ödeme okunamadı. Formdaki tutarı elle tamamlayabilirsin.',
                    ),
                  if (fields.litersMilli != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Alınan yakıt: ${Formatters.number(fields.litersMilli! / 1000)} litre',
                      ),
                      value: useLiters,
                      onChanged: (value) => update(() => useLiters = value!),
                    ),
                  if (fields.amountKurus != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Toplam ödeme: ${Formatters.preciseMoney(fields.amountKurus! / 100)}',
                      ),
                      value: useAmount,
                      onChanged: (value) => update(() => useAmount = value!),
                    ),
                  const Text(
                    'Kilometreyi ve depo doluluğunu kendin belirt. Market alışverişi de içeren fişlerde yakıt tutarını ayrıca kontrol et.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: !useLiters && !useAmount
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Forma doldur'),
              ),
            ],
          ),
        ),
      );
      if (mounted && approved == true) {
        setState(() {
          if (useLiters) {
            liters.text = (fields.litersMilli! / 1000)
                .toStringAsFixed(3)
                .replaceAll('.', ',');
          }
          if (useAmount) {
            amount.text = Formatters.decimal(fields.amountKurus! / 100);
          }
          receiptMessage =
              'Fiş bilgileri forma dolduruldu. Eksikleri tamamlayıp kontrol ettikten sonra kaydet.';
        });
      }
    } on FuelReceiptFailure catch (failure) {
      if (mounted) setState(() => receiptMessage = failure.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => receiptMessage =
              'Fiş okunamadı. Tekrar deneyebilir veya elle girebilirsin.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          readingReceipt = false;
          reviewingReceipt = false;
        });
      }
    }
  }

  Widget numberField(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, helperText: helper),
      validator: validator,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final parsedLiters = RecordCalculations.scaledNumber(liters.text, 3);
    final parsedAmount = RecordCalculations.scaledNumber(amount.text, 2);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.record != null
                ? 'Kaydı düzenle'
                : isFuel
                ? 'Yakıt ekle'
                : 'Masraf ekle',
          ),
          leading: IconButton(
            tooltip: 'Kayıtlara dön',
            onPressed: busy ? null : () => context.go('/records'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: PageContent(
          children: [
            Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    widget.vehicle.name,
                    subtitle: widget.vehicle.plate,
                  ),
                  if (isFuel) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yakıt fişinden doldur',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Fişteki litre ve toplam ödemeyi cihazında okuyup forma aktar. Fotoğraf hesabına yüklenmez.',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => readReceipt(
                                          FuelReceiptSource.camera,
                                        ),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Fiş fotoğrafı çek'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => readReceipt(
                                          FuelReceiptSource.gallery,
                                        ),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Fiş fotoğrafı seç'),
                                ),
                              ],
                            ),
                            if (readingReceipt) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                              const Text('Fiş okunuyor…'),
                            ],
                            if (receiptMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(receiptMessage!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (selected != null && mounted) {
                              setState(() => date = selected);
                            }
                          },
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Tarih: ${Formatters.date(date)}'),
                  ),
                  const SizedBox(height: 16),
                  numberField('Kilometre', km, (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed < 0 || parsed > 10000000
                        ? '0–10.000.000 arasında tam sayı gir.'
                        : null;
                  }),
                  numberField(
                    'Toplam tutar (TL)',
                    amount,
                    (value) {
                      final parsed = RecordCalculations.scaledNumber(
                        value ?? '',
                        2,
                      );
                      return parsed == null || parsed <= 0 || parsed > 100000000
                          ? 'Geçerli, pozitif tutar gir. Örnek: 1250,50'
                          : null;
                    },
                    helper: 'Örnek: 1250,50 — binlik ayırıcı kullanma.',
                  ),
                  if (isFuel) ...[
                    numberField('Alınan yakıt (litre)', liters, (value) {
                      final parsed = RecordCalculations.scaledNumber(
                        value ?? '',
                        3,
                      );
                      return parsed == null || parsed <= 0 || parsed > 1000000
                          ? '0–1000 arasında pozitif litre gir. Örnek: 42,3'
                          : null;
                    }),
                    DropdownButtonFormField<String>(
                      initialValue: fuel,
                      decoration: const InputDecoration(
                        labelText: 'Yakıt türü',
                      ),
                      items: ['Benzin', 'Dizel', 'LPG', 'Hibrit']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => fuel = value!),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Depoyu tamamen doldurdum'),
                      subtitle: const Text(
                        'Tüketim hesabı için iki dolu depo kaydı gerekir.',
                      ),
                      value: fullTank,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => fullTank = value),
                    ),
                    if (parsedLiters != null &&
                        parsedLiters > 0 &&
                        parsedAmount != null)
                      Text(
                        'Litre fiyatı: ${Formatters.preciseMoney(parsedAmount / 100 / (parsedLiters / 1000))}',
                      ),
                  ] else
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: expenseCategories
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() => category = value!),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notes,
                    enabled: !busy,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama / not (isteğe bağlı)',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: busy && !reviewingReceipt
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kaydı kaydet'),
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
}
