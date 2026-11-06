import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/activity_controller.dart';
import '../repositories/offline_activity_repository.dart';
import '../repositories/activity_repository.dart';
import '../../../core/utils/formatters.dart';

class OfflineSyncScreen extends ConsumerWidget {
  const OfflineSyncScreen({super.key});
  Future<void> action(
    BuildContext context,
    Future<void> Function() task,
  ) async {
    try {
      await task();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is RecordFailure
                  ? error.message
                  : 'İşlem tamamlanamadı. Tekrar dene.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineRecordStateProvider).asData?.value;
    final repository = ref.watch(activityRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cihazdaki kayıtlar')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            state?.online == true ? 'Bağlantı hazır' : 'Çevrimdışı kullanım',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Masraf ve yakıt kayıtların önce bu cihazda saklanır. Bağlantı geldiğinde hesabına otomatik aktarılır. Önceden açtığın araç ve geçmiş bilgilerini çevrimdışı görebilirsin. Rota, istasyon arama ve belge yükleme için internet gerekir.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Gönderilmeyi bekleyen kayıtlar bu cihazdadır. Uygulama verilerini silmek veya uygulamayı kaldırmak bu kopyaları silebilir.',
          ),
          if (state?.issue != null)
            Text(
              state!.issue!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          if (repository is OfflineActivityRepository)
            FilledButton.icon(
              onPressed: state?.online == true && state?.syncing != true
                  ? () => action(context, repository.retry)
                  : null,
              icon: const Icon(Icons.sync),
              label: const Text('Şimdi eşitle'),
            ),
          if (state?.pending.isEmpty ?? true)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text('Bekleyen kayıt yok.'),
            ),
          for (final pending in state?.pending ?? <PendingRecord>[])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${pending.record.title} • ${Formatters.preciseMoney(pending.record.amount)}',
                    ),
                    Text(
                      '${Formatters.date(pending.record.date)} • ${Formatters.number(pending.record.odometerKm)} km',
                    ),
                    Text(
                      pending.error ??
                          (pending.archived == null
                              ? 'Gönderilmeyi bekliyor'
                              : pending.archived!
                              ? 'Kaldırma bekliyor'
                              : 'Geri alma bekliyor'),
                    ),
                    if (repository is OfflineActivityRepository)
                      TextButton(
                        onPressed: () => action(context, () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text(
                                'Cihazdaki değişiklikten vazgeç?',
                              ),
                              content: const Text(
                                'Bu kayıt için telefonda bekleyen ekleme, düzenleme ve kaldırma işlemleri silinecek. Firebase’deki kayıt korunacak.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Vazgeç'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Bekleyen değişiklikleri sil',
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await repository.discard(pending.key);
                          }
                        }),
                        child: const Text('Bekleyen değişikliklerden vazgeç'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
