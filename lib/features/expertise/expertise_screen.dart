import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/widgets/page_content.dart';
import '../vehicles/controllers/vehicle_controller.dart';
import '../vehicles/widgets/vehicle_scope.dart';
import 'expertise_record.dart';
import 'expertise_repository.dart';
import 'expertise_diagram.dart';

class ExpertiseScreen extends ConsumerWidget {
  const ExpertiseScreen({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => VehicleScope(
    allowEmpty: true,
    builder: (_) {
      final car = ref
          .watch(vehiclesProvider)
          .asData!
          .value
          .where((v) => v.id == vehicleId)
          .firstOrNull;
      if (car == null) {
        return const Scaffold(body: Center(child: Text('Araç bulunamadı.')));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Araç ekspertizi')),
        body: ref
            .watch(expertiseProvider(vehicleId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(expertiseProvider(vehicleId)),
                  child: const Text('Ekspertiz yüklenemedi. Tekrar dene'),
                ),
              ),
              data: (entry) => _ExpertiseEditor(
                key: ValueKey(vehicleId),
                vehicleId: vehicleId,
                vehicleName: '${car.name} • ${car.plate}',
                initial: entry ?? ExpertiseRecord(),
              ),
            ),
      );
    },
  );
}

class _ExpertiseEditor extends ConsumerStatefulWidget {
  const _ExpertiseEditor({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
    required this.initial,
  });
  final String vehicleId, vehicleName;
  final ExpertiseRecord initial;
  @override
  ConsumerState<_ExpertiseEditor> createState() => _ExpertiseEditorState();
}

class _ExpertiseEditorState extends ConsumerState<_ExpertiseEditor> {
  late Map<String, String> parts;
  late TextEditingController notes;
  late String reportId, reportName;
  Uint8List? pendingPdf;
  bool busy = false, dirty = false;
  String? error;
  @override
  void initState() {
    super.initState();
    parts = {...widget.initial.parts};
    notes = TextEditingController(text: widget.initial.notes);
    reportId = widget.initial.reportId;
    reportName = widget.initial.reportName;
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> select(String key) async {
    if (busy) return;
    final status = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  expertiseParts[key]!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final item in expertiseStatuses.entries)
                ListTile(
                  leading: Icon(Icons.circle, color: expertiseColor(item.key)),
                  title: Text(item.value),
                  trailing: parts[key] == item.key
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, item.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (status != null && mounted) {
      setState(() {
        parts[key] = status;
        dirty = true;
      });
    }
  }

  Future<void> pick() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        dialogTitle: 'Ekspertiz raporu seç',
      );
      if (file == null) return;
      final length = await file.length();
      if (length == null || length > maxExpertisePdfBytes) {
        throw const ExpertiseFailure('En fazla 10 MB büyüklüğünde PDF seç.');
      }
      final bytes = await file.readAsBytes();
      if (!isExpertisePdf(bytes)) {
        throw const ExpertiseFailure('Seçtiğin dosya geçerli bir PDF değil.');
      }
      final name = file.name;
      if (name.length > 200) {
        throw const ExpertiseFailure(
          'Dosya adı çok uzun. Kısaltıp tekrar seç.',
        );
      }
      if (mounted) {
        setState(() {
          pendingPdf = bytes;
          reportName = name;
          dirty = true;
          error = null;
        });
      }
    } on ExpertiseFailure catch (e) {
      message(e.message);
    } catch (_) {
      message('PDF seçilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openPdf() async {
    if (busy) return;
    final repo = ref.read(expertiseRepositoryProvider);
    setState(() => busy = true);
    try {
      final data =
          pendingPdf ?? await repo!.readPdf(widget.vehicleId, reportId);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(reportName)),
              body: PdfViewer.data(data, sourceName: reportName),
            ),
          ),
        );
      }
    } catch (_) {
      message('Rapor açılamadı. Bağlantını kontrol edip tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    final repo = ref.read(expertiseRepositoryProvider);
    if (repo == null) {
      message('Hesap bağlantısı hazır değil. Tekrar giriş yap.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    String? uploaded;
    final previous = reportId;
    try {
      if (notes.text.trim().length > 2000) {
        throw const ExpertiseFailure(
          'Notlar en fazla 2.000 karakter olabilir.',
        );
      }
      if (pendingPdf != null) {
        uploaded = await repo.upload(widget.vehicleId, pendingPdf!);
      }
      final record = ExpertiseRecord(
        parts: parts,
        notes: notes.text.trim(),
        reportId: uploaded ?? reportId,
        reportName: reportName,
      );
      await repo.save(widget.vehicleId, record);
      if (mounted) {
        setState(() {
          reportId = record.reportId;
          pendingPdf = null;
          dirty = false;
        });
      }
      message('Ekspertiz bilgileri kaydedildi.');
      if (previous.isNotEmpty && previous != record.reportId) {
        try {
          await repo.removePdf(widget.vehicleId, previous);
        } catch (_) {
          /* The saved record remains valid if old file cleanup fails. */
        }
      }
    } catch (e) {
      if (uploaded != null) {
        try {
          await repo.removePdf(widget.vehicleId, uploaded);
        } catch (_) {}
      }
      if (mounted) {
        setState(
          () => error = e is ExpertiseFailure
              ? e.message
              : 'Ekspertiz kaydedilemedi. PDF yüklerken sorun varsa Firebase Storage bağlantısını kontrol et; seçimlerin burada duruyor.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageContent(
    children: [
      SectionTitle(
        widget.vehicleName,
        subtitle:
            'Parçaya dokun, durumunu seç. Şemanın üstü aracın önüdür; sol/sağ sürücüye göredir.',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('ÖN', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              ExpertiseDiagram(parts: parts, onSelect: select),
              const SizedBox(height: 10),
              const Text('ARKA'),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final item in expertiseStatuses.entries)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: expertiseColor(item.key),
                        ),
                        const SizedBox(width: 5),
                        Text(item.value),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const SectionTitle(
        'Parça durumları',
        subtitle: 'İşaretlenmeyen parçalar orijinal kabul edilmez.',
      ),
      for (final part in expertiseParts.entries)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(
            Icons.circle,
            size: 14,
            color: expertiseColor(parts[part.key]!),
          ),
          title: Text(part.value),
          subtitle: Text(expertiseStatuses[parts[part.key]]!),
          trailing: const Icon(Icons.chevron_right),
          onTap: busy ? null : () => select(part.key),
        ),
      const SizedBox(height: 20),
      TextField(
        controller: notes,
        enabled: !busy,
        maxLength: 2000,
        minLines: 2,
        maxLines: 5,
        onChanged: (_) => setState(() => dirty = true),
        decoration: const InputDecoration(
          labelText: 'Ekspertiz notları',
          hintText: 'Şasi, motor, mekanik kontrol veya diğer bulgular',
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 34),
              const SizedBox(height: 10),
              const Text('Ekspertiz raporu', textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                reportName.isEmpty
                    ? 'İsteğe bağlı • PDF, en fazla 10 MB'
                    : reportName,
                textAlign: TextAlign.center,
              ),
              if (pendingPdf != null)
                const Text(
                  'Kaydedilince hesabına yüklenecek',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : pick,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  reportName.isEmpty
                      ? 'PDF raporu ekle'
                      : 'PDF raporunu değiştir',
                ),
              ),
              if (reportName.isNotEmpty)
                TextButton.icon(
                  onPressed: busy ? null : openPdf,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Raporu görüntüle'),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (busy) const LinearProgressIndicator(),
      FilledButton.icon(
        onPressed: busy ? null : save,
        icon: const Icon(Icons.save_outlined),
        label: Text(
          busy
              ? 'İşleniyor…'
              : dirty
              ? 'Değişiklikleri kaydet'
              : 'Ekspertizi kaydet',
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Bu kayıt kendi beyanınızdır; profesyonel ekspertiz raporu yerine geçmez.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}
