import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/status_colors.dart';
import '../../core/widgets/page_content.dart';
import '../vehicles/controllers/vehicle_controller.dart';
import '../vehicles/models/vehicle.dart';
import '../vehicles/widgets/vehicle_scope.dart';
import '../records/utils/record_calculations.dart';
import 'maintenance_entry.dart';
import 'maintenance_repository.dart';
import 'maintenance_history_card.dart';
import 'maintenance_notification_preferences.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({
    super.key,
    required this.vehicleId,
    this.latestOnly = false,
  });
  final bool latestOnly;
  final String vehicleId;
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
      void edit([MaintenanceEntry? entry]) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MaintenanceForm(vehicle: vehicle, initial: entry),
        ),
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(latestOnly ? 'Son bakım detayları' : 'Bakım takibi'),
        ),
        body: ref
            .watch(maintenanceProvider(vehicleId))
            .when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(maintenanceProvider(vehicleId)),
                  child: const Text('Bakımlar yüklenemedi. Tekrar dene'),
                ),
              ),
              data: (records) {
                final sorted = sortMaintenance(records);
                final history = latestOnly ? sorted.take(1).toList() : sorted;
                final latest = history.firstOrNull;
                final colors = Theme.of(context).colorScheme;
                final color = latest == null
                    ? colors.primary
                    : StatusColors.foreground(
                        context,
                        latest.overdue(vehicle.currentKm)
                            ? RecordStatus.overdue
                            : latest.approaching(vehicle.currentKm)
                            ? RecordStatus.attention
                            : RecordStatus.valid,
                      );
                return PageContent(
                  children: [
                    SectionTitle(
                      vehicle.name,
                      subtitle:
                          '${vehicle.plate} • Güncel: ${Formatters.number(vehicle.currentKm)} km',
                    ),
                    if (!latestOnly) ...[
                      FilledButton.icon(
                        onPressed: () => edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Bakım kaydı ekle'),
                      ),
                      const SizedBox(height: 20),
                      if (latest == null)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(22),
                            child: Text(
                              'Henüz bakım kaydın yok. Son bakımda neler değiştiğini kaydet; sonraki bakımını birlikte takip edelim.',
                            ),
                          ),
                        )
                      else
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: color),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.build_circle_outlined,
                                      color: color,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        latest.status(vehicle.currentKm),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Son bakım: ${Formatters.date(latest.date)} • ${Formatters.number(latest.odometerKm)} km',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sonraki bakım: ${Formatters.number(latest.nextKm)} km',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${Formatters.number((latest.nextKm - vehicle.currentKm).clamp(0, 10000000))} km kaldı.',
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    SectionTitle(
                      latestOnly
                          ? 'Son bakımda neler değişti?'
                          : 'Bakım geçmişi',
                      subtitle:
                          'Her bakımda değişen parçalar ve yapılan işlemler.',
                    ),
                    if (latest != null &&
                        latest.approaching(vehicle.currentKm) &&
                        !latestOnly) ...[
                      const MaintenanceNotificationPreferences(),
                      const SizedBox(height: 16),
                    ],
                    for (var i = 0; i < history.length; i++)
                      MaintenanceHistoryCard(
                        key: ValueKey('$latestOnly-${history[i].id}'),
                        entry: history[i],
                        latest: i == 0,
                        onEdit: () => edit(history[i]),
                      ),
                    if (latestOnly)
                      OutlinedButton(
                        onPressed: () =>
                            context.replace('/vehicles/$vehicleId/maintenance'),
                        child: const Text('Tüm bakım geçmişi'),
                      ),
                  ],
                );
              },
            ),
      );
    },
  );
}

class MaintenanceForm extends ConsumerStatefulWidget {
  const MaintenanceForm({super.key, required this.vehicle, this.initial});
  final Vehicle vehicle;
  final MaintenanceEntry? initial;
  @override
  ConsumerState<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends ConsumerState<MaintenanceForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController km,
      intervalKm,
      amount,
      details,
      service,
      notes;
  late DateTime date;
  late final Set<String> items;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final entry = widget.initial;
    date = entry?.date ?? DateUtils.dateOnly(DateTime.now());
    km = TextEditingController(
      text: '${entry?.odometerKm ?? widget.vehicle.currentKm}',
    );
    intervalKm = TextEditingController(text: '${entry?.intervalKm ?? 10000}');
    amount = TextEditingController(
      text: entry == null || entry.amountKurus == 0
          ? ''
          : (entry.amountKurus / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    details = TextEditingController(text: entry?.details);
    service = TextEditingController(text: entry?.service);
    notes = TextEditingController(text: entry?.notes);
    items = {...?entry?.items};
  }

  @override
  void dispose() {
    for (final controller in [
      km,
      intervalKm,
      amount,
      details,
      service,
      notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? integer(String? value, int min, int max) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed < min || parsed > max
        ? '$min–$max arasında tam sayı gir.'
        : null;
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (items.isEmpty && details.text.trim().isEmpty) {
      setState(() => error = 'Değişen bir parça seç veya yapılan işlemi yaz.');
      return;
    }
    final repository = ref.read(maintenanceRepositoryProvider);
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
        widget.vehicle.id,
        MaintenanceEntry(
          id: widget.initial?.id ?? '',
          date: date,
          odometerKm: int.parse(km.text.trim()),
          intervalKm: int.parse(intervalKm.text.trim()),
          amountKurus: amount.text.trim().isEmpty
              ? 0
              : RecordCalculations.scaledNumber(amount.text, 2)!,
          items: items.toList(),
          details: details.text.trim(),
          service: service.text.trim(),
          notes: notes.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } on MaintenanceFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Bakım kaydedilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.initial == null ? 'Bakım kaydı ekle' : 'Bakım kaydını düzenle',
      ),
    ),
    body: Form(
      key: form,
      child: PageContent(
        children: [
          SectionTitle(widget.vehicle.name, subtitle: widget.vehicle.plate),
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
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('Bakım tarihi: ${Formatters.date(date)}'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: km,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Bakım kilometresi'),
            validator: (value) => integer(value, 0, widget.vehicle.currentKm),
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            'Neler değişti?',
            subtitle: 'Bu bakımda değişen parçaları seç.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in maintenanceItems.entries)
                FilterChip(
                  label: Text(item.value),
                  selected: items.contains(item.key),
                  onSelected: busy
                      ? null
                      : (selected) => setState(() {
                          if (selected) {
                            items.add(item.key);
                          } else {
                            items.remove(item.key);
                          }
                        }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: details,
            enabled: !busy,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Diğer işlemler / parça ayrıntıları',
              hintText: 'Örn. yağ markası, filtre kodu, fren kontrolü',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: service,
            enabled: !busy,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Servis / usta (isteğe bağlı)',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: amount,
            enabled: !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Bakım tutarı (₺, isteğe bağlı)',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final parsed = RecordCalculations.scaledNumber(value, 2);
              return parsed == null || parsed < 0 || parsed > 100000000
                  ? 'Geçerli bir tutar gir.'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Tutar bakım geçmişinde saklanır. Gider toplamına eklemek için ayrıca masraf kaydı oluşturabilirsin.',
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            'Sonraki bakım',
            subtitle:
                'Kaç kilometrede bir bakım yapılacağını aracının bakım planına göre belirle.',
          ),
          TextFormField(
            controller: intervalKm,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Bakım aralığı (km)'),
            validator: (value) => integer(value, 1000, 100000),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: notes,
            enabled: !busy,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Notlar (isteğe bağlı)',
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(busy ? 'Kaydediliyor…' : 'Bakımı kaydet'),
          ),
        ],
      ),
    ),
  );
}
