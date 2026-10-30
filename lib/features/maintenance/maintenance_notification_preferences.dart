import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'maintenance_reminders.dart';

class MaintenanceNotificationPreferences extends ConsumerWidget {
  const MaintenanceNotificationPreferences({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(maintenanceReminderManagerProvider);
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
                title: const Text('Bakım bildirimleri'),
                subtitle: const Text(
                  'Hedef kilometreye 2.000 km kala hatırlat',
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
                'Kilometreni güncellediğinde veya uygulamayı açtığında kontrol edilir. Bildirime dokunarak son bakımda değişen parçaları görebilirsin.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
