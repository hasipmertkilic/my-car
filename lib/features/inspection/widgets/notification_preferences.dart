import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/reminder_manager.dart';

class NotificationPreferences extends ConsumerWidget {
  const NotificationPreferences({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(reminderManagerProvider);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Muayene bildirimleri'),
                subtitle: Text(
                  manager.gateway.canSchedule
                      ? '30 gün, 7 gün ve muayene günü hatırlatması'
                      : 'Web: uygulama açıkken yaklaşan muayene bildirimi',
                ),
                value: manager.enabled,
                onChanged: manager.busy || manager.owner == null
                    ? null
                    : manager.setEnabled,
              ),
              if (manager.busy) const LinearProgressIndicator(),
              if (manager.error != null)
                Text(
                  manager.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Text(
                'Bu cihaz için geçerlidir. Bildirim kapalı olsa da ana ekranda kalan süre gösterilir.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
