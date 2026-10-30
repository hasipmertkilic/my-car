import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/utils/formatters.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../../records/utils/record_calculations.dart';
import '../models/insurance_policy.dart';
import '../repositories/policy_repository.dart';
import '../services/policy_document_importer.dart';
import '../widgets/policy_document_review.dart';

class PolicyEditorScreen extends ConsumerWidget {
  const PolicyEditorScreen({super.key, required this.vehicleId, this.policyId});
  final String vehicleId;
  final String? policyId;
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
        return const Scaffold(body: Center(child: Text('Araç bulunamadı.')));
      }
      if (policyId == null) {
        return PolicyForm(vehicleId: vehicleId, name: vehicle.name);
      }
      return ref
          .watch(policiesProvider(vehicleId))
          .when(
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: false,
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Scaffold(
              appBar: AppBar(title: const Text('Poliçe')),
              body: Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(policiesProvider(vehicleId)),
                  child: const Text('Yüklenemedi. Tekrar dene'),
                ),
              ),
            ),
            data: (policies) {
              final policy = policies
                  .where((p) => p.id == policyId)
                  .firstOrNull;
              if (policy == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Poliçe')),
                  body: const Center(child: Text('Poliçe bulunamadı.')),
                );
              }
              return PolicyForm(
                key: ValueKey(policy.id),
                vehicleId: vehicleId,
                name: vehicle.name,
                initial: policy,
              );
            },
          );
    },
  );
}

class PolicyForm extends ConsumerStatefulWidget {
  const PolicyForm({
    super.key,
    required this.vehicleId,
    required this.name,
    this.initial,
  });
  final String vehicleId, name;
  final InsurancePolicy? initial;
  @override
  ConsumerState<PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends ConsumerState<PolicyForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController company, number, premium, notes;
  late String kind, level;
  int? step;
  late DateTime startDate, endDate;
  bool busy = false;
  bool reading = false;
  bool reviewing = false;
  String? imported;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    final now = DateTime.now();
    kind = p?.kind ?? 'traffic';
    level = p?.level ?? '';
    step = p?.step;
    startDate = p?.startDate ?? DateTime(now.year, now.month, now.day);
    endDate =
        p?.endDate ??
        DateTime(
          startDate.year + 1,
          startDate.month,
          math.min(
            startDate.day,
            DateTime(startDate.year + 1, startDate.month + 1, 0).day,
          ),
        );
    company = TextEditingController(text: p?.company);
    number = TextEditingController(text: p?.number);
    premium = TextEditingController(
      text: p == null ? '' : Formatters.decimal(p.premiumKurus / 100),
    );
    notes = TextEditingController(text: p?.notes);
  }

  @override
  void dispose() {
    company.dispose();
    number.dispose();
    premium.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> chooseDate(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: start ? startDate : endDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (value != null && mounted) {
      setState(() {
        if (start) {
          startDate = value;
        } else {
          endDate = value;
        }
        error = null;
      });
    }
  }

  Future<void> importDocument(PolicyDocumentSource source) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      reading = true;
      error = null;
    });
    try {
      final fields = await ref
          .read(policyDocumentImporterProvider)
          .read(source);
      if (!mounted || fields == null) return;
      if (fields.isEmpty) {
        setState(
          () => imported =
              'Poliçe alanları güvenle okunamadı. Daha net bir belge seçebilir veya bilgileri elle girebilirsin. Mevcut alanların korundu.',
        );
        return;
      }
      setState(() {
        reading = false;
        reviewing = true;
      });
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (_) => PolicyDocumentReview(fields: fields),
      );
      if (!mounted || selected == null) return;
      setState(() {
        if (selected.contains('company')) company.text = fields.company!;
        if (selected.contains('number')) number.text = fields.number!;
        if (selected.contains('premium')) {
          premium.text = Formatters.decimal(fields.premiumKurus! / 100);
        }
        if (selected.contains('start')) startDate = fields.startDate!;
        if (selected.contains('end')) endDate = fields.endDate!;
        if (selected.contains('kind') && kind != fields.kind) {
          kind = fields.kind!;
          step = null;
          level = kind == 'casco' ? 'Kasko' : '';
        }
        if (kind == 'traffic' && selected.contains('step')) step = fields.step;
        if (kind == 'casco' && selected.contains('level')) {
          level = fields.level!;
        }
        imported =
            'Seçtiğin bilgiler forma dolduruldu. Tarihleri, tutarı ve diğer alanları kontrol edip eksikleri tamamladıktan sonra kaydet.';
      });
    } on DocumentReadFailure catch (failure) {
      if (mounted) setState(() => imported = failure.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => imported =
              'Belge okunamadı. Bilgileri elle girebilir veya tekrar deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          reading = false;
          reviewing = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) {
      return;
    }
    if (!endDate.isAfter(startDate)) {
      setState(() => error = 'Bitiş tarihi başlangıç tarihinden sonra olmalı.');
      return;
    }
    final repository = ref.read(policyRepositoryProvider);
    if (repository == null) {
      setState(() => error = 'Hesap bağlantısı hazır değil. Tekrar dene.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.save(
        widget.vehicleId,
        InsurancePolicy(
          id: widget.initial?.id ?? '',
          kind: kind,
          company: company.text.trim(),
          number: number.text.trim(),
          startDate: startDate,
          endDate: endDate,
          premiumKurus: RecordCalculations.scaledNumber(premium.text, 2)!,
          level: kind == 'casco' ? level : '',
          step: kind == 'traffic' ? step : null,
          notes: notes.text.trim(),
        ),
      );
      if (mounted) {
        context.go('/vehicles/${widget.vehicleId}/policies');
      }
    } on PolicyFailure catch (failure) {
      if (mounted) {
        setState(() => error = failure.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Poliçe kaydedilemedi. Tekrar dene.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null ? 'Poliçe ekle' : 'Poliçeyi düzenle',
        ),
        leading: IconButton(
          tooltip: 'Poliçelere dön',
          onPressed: busy
              ? null
              : () => context.go('/vehicles/${widget.vehicleId}/policies'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: PageContent(
        children: [
          SectionTitle(
            widget.name,
            subtitle: 'Bilgileri poliçe belgendeki şekilde kaydet.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belgeden doldur',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'e-Devlet’ten indirdiğin PDF’yi veya poliçe fotoğrafını seç. Bilgiler cihazında okunur; belge hesabına yüklenmez.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => importDocument(PolicyDocumentSource.file),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('PDF / fotoğraf seç'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => importDocument(PolicyDocumentSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Fotoğraf çek'),
                      ),
                    ],
                  ),
                  if (reading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const Text(
                      'Belge okunuyor… Çok sayfalı belgeler biraz sürebilir.',
                    ),
                  ],
                  if (imported != null) ...[
                    const SizedBox(height: 12),
                    Text(imported!),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'PDF, JPG veya PNG • En fazla 20 MB / 10 PDF sayfası. Fotoğrafta sayfanın tamamı net ve düz görünsün.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('policy-kind-$kind'),
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Poliçe türü'),
                  items: const [
                    DropdownMenuItem(
                      value: 'traffic',
                      child: Text('Trafik sigortası'),
                    ),
                    DropdownMenuItem(value: 'casco', child: Text('Kasko')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          kind = value!;
                          level = kind == 'casco' ? 'Kasko' : '';
                          step = null;
                        }),
                ),
                const SizedBox(height: 16),
                field(company, 'Sigorta şirketi', 100),
                const SizedBox(height: 16),
                field(number, 'Poliçe numarası', 100),
                const SizedBox(height: 16),
                if (kind == 'traffic')
                  DropdownButtonFormField<int>(
                    key: ValueKey('traffic-step-$step'),
                    initialValue: step ?? -1,
                    decoration: const InputDecoration(
                      labelText: 'Hasarsızlık basamağı',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Belirtilmedi'),
                      ),
                      for (var i = 0; i <= 8; i++)
                        DropdownMenuItem(value: i, child: Text('$i. basamak')),
                    ],
                    onChanged: busy
                        ? null
                        : (value) =>
                              setState(() => step = value == -1 ? null : value),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('casco-level-$level'),
                    initialValue: level,
                    decoration: const InputDecoration(
                      labelText: 'Kasko kapsamı / seviyesi',
                    ),
                    items: cascoLevels
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) => setState(() => level = value!),
                  ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => chooseDate(true),
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Başlangıç: ${Formatters.date(startDate)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => chooseDate(false),
                  icon: const Icon(Icons.event_available),
                  label: Text('Bitiş: ${Formatters.date(endDate)}'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: premium,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Poliçe tutarı (₺)',
                    hintText: 'Örn. 12500,50',
                  ),
                  validator: (value) {
                    final amount = RecordCalculations.scaledNumber(
                      value ?? '',
                      2,
                    );
                    return amount == null || amount <= 0 || amount > 100000000
                        ? '0–1.000.000 ₺ aralığında pozitif bir tutar gir.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notes,
                  enabled: !busy,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Teminatlar / notlar (isteğe bağlı)',
                    hintText: 'Örn. ikame araç, yol yardım, cam teminatı',
                  ),
                  validator: (value) => (value?.length ?? 0) > 1000
                      ? 'En fazla 1000 karakter gir.'
                      : null,
                ),
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
                  child: busy && !reviewing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Poliçeyi kaydet'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget field(TextEditingController controller, String label, int max) =>
      TextFormField(
        controller: controller,
        enabled: !busy,
        maxLength: max,
        decoration: InputDecoration(labelText: label),
        validator: (value) => (value?.trim().isEmpty ?? true)
            ? '$label bilgisini gir.'
            : value!.length > max
            ? 'En fazla $max karakter gir.'
            : null,
      );
}
