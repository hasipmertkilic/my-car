import 'package:flutter/material.dart';
import '../../../core/utils/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../models/inspection_schedule.dart';
import '../repositories/inspection_repository.dart';
import '../widgets/notification_preferences.dart';

class InspectionScreen extends ConsumerWidget {
  const InspectionScreen({super.key, required this.vehicleId});
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
        return Scaffold(
          appBar: AppBar(title: const Text('Muayene')),
          body: const Center(child: Text('Araç bulunamadı. Garajına dön.')),
        );
      }
      return ref
          .watch(inspectionProvider(vehicleId))
          .when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            data: (schedule) => InspectionForm(
              key: ValueKey(vehicleId),
              vehicleId: vehicleId,
              name: vehicle.name,
              initial: schedule,
            ),
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Scaffold(
              appBar: AppBar(title: const Text('Muayene')),
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      ref.invalidate(inspectionProvider(vehicleId)),
                  child: const Text('Yüklenemedi. Tekrar dene'),
                ),
              ),
            ),
          );
    },
  );
}

class InspectionForm extends ConsumerStatefulWidget {
  const InspectionForm({
    super.key,
    required this.vehicleId,
    required this.name,
    this.initial,
  });
  final String vehicleId, name;
  final InspectionSchedule? initial;
  @override
  ConsumerState<InspectionForm> createState() => _InspectionFormState();
}

class _InspectionFormState extends ConsumerState<InspectionForm> {
  late DateTime date;
  late int years;
  late final TextEditingController notes;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    date = widget.initial?.lastDate ?? DateTime(now.year, now.month, now.day);
    years = widget.initial?.intervalYears ?? 2;
    notes = TextEditingController(text: widget.initial?.notes);
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    final repository = ref.read(inspectionRepositoryProvider);
    if (repository == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.save(
        widget.vehicleId,
        InspectionSchedule(
          lastDate: date,
          intervalYears: years,
          notes: notes.text.trim(),
        ),
      );
      if (mounted) {
        context.go('/summary');
      }
    } on InspectionFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Muayene kaydedilemedi. Tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = InspectionSchedule(lastDate: date, intervalYears: years);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Muayene takibi'),
          leading: IconButton(
            tooltip: 'Özete dön',
            onPressed: busy ? null : () => context.go('/summary'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: PageContent(
          children: [
            SectionTitle(
              widget.name,
              subtitle: 'Son muayeneyi ve tekrar aralığını kaydet.',
            ),
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
              label: Text('Son muayene: ${Formatters.date(date)}'),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: years,
              decoration: const InputDecoration(
                labelText: 'Tekrar kaç yıl sonra?',
              ),
              items: List.generate(
                5,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('${i + 1} yıl sonra'),
                ),
              ),
              onChanged: busy
                  ? null
                  : (value) => setState(() => years = value!),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sonraki muayene: ${Formatters.date(schedule.nextDate)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      schedule.status(DateTime.now()),
                      style: TextStyle(
                        color: StatusColors.foreground(
                          context,
                          StatusColors.forDays(
                            schedule.daysUntil(DateTime.now()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aralığı aracının muayene belgesindeki bilgilere göre seç. 29 Şubat için sonraki yılın uygun son günü kullanılır.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: notes,
              enabled: !busy,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                    : const Text('Muayeneyi kaydet'),
              ),
            ),
            const SizedBox(height: 24),
            const NotificationPreferences(),
          ],
        ),
      ),
    );
  }
}
