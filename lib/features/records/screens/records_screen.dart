import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../../vehicles/widgets/vehicle_scope.dart';
import '../controllers/activity_controller.dart';
import '../models/activity_record.dart';
import '../repositories/activity_repository.dart';
import '../widgets/activity_scope.dart';
import '../widgets/activity_card.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});
  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  String filter = 'Tümü';
  bool busy = false;
  Future<void> changeArchive(String vehicleId, String id, bool archived) async {
    if (busy) return;
    final repository = ref.read(activityRepositoryProvider);
    if (repository == null) return;
    setState(() => busy = true);
    try {
      await repository.archive(vehicleId, id, archived);
      if (mounted && archived) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: const Text('Kayıt kaldırıldı.'),
            action: SnackBarAction(
              label: 'Geri al',
              onPressed: () => changeArchive(vehicleId, id, false),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is RecordFailure
                  ? error.message
                  : 'Kayıt değiştirilemedi. Tekrar dene.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(String vehicleId, ActivityRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı kaldır?'),
        content: const Text(
          'Kayıt gider ve tüketim hesaplarından çıkarılacak. İşlemden sonra Geri al kullanabilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await changeArchive(vehicleId, record.id, true);
    }
  }

  @override
  Widget build(BuildContext context) => VehicleScope(
    builder: (vehicle) => ActivityScope(
      vehicleId: vehicle!.id,
      builder: (allRecords) {
        final records = allRecords
            .where(
              (r) =>
                  filter == 'Tümü' ||
                  (filter == 'Yakıt' ? r.isFuel : !r.isFuel),
            )
            .toList();
        return PageContent(
          children: [
            PageHeading(
              'Kayıt defteri',
              eyebrow: 'YAKIT VE HARCAMALAR',
              subtitle: vehicle.name,
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => context.push('/vehicles/${vehicle.id}/fuel/new'),
                  icon: const Icon(Icons.local_gas_station),
                  label: const Text('Yakıt ekle'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            context.push('/vehicles/${vehicle.id}/expense/new'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Masraf ekle'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'Tümü', label: Text('Tümü')),
                ButtonSegment(value: 'Yakıt', label: Text('Yakıt')),
                ButtonSegment(value: 'Masraf', label: Text('Masraf')),
              ],
              selected: {filter},
              onSelectionChanged: (selection) =>
                  setState(() => filter = selection.single),
            ),
            const SizedBox(height: 20),
            if (records.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 44),
                      SizedBox(height: 12),
                      Text('Henüz işlem kaydı yok.'),
                    ],
                  ),
                ),
              ),
            for (final record in records) ...[
              ActivityCard(
                record: record,
                onEdit: busy
                    ? null
                    : () => context.push(
                        '/vehicles/${vehicle.id}/records/${record.id}/edit',
                      ),
                onRemove: busy ? null : () => remove(vehicle.id, record),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    ),
  );
}
