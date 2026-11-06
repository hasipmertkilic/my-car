import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/activity_controller.dart';

class OfflineStatusBar extends ConsumerWidget {
  const OfflineStatusBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineRecordStateProvider).asData?.value;
    if (state == null ||
        (state.online && state.pending.isEmpty && state.issue == null)) {
      return const SizedBox.shrink();
    }
    final errors = state.pending.where((p) => p.error != null).length;
    final text =
        state.issue ??
        (errors > 0
            ? '$errors kayıt kontrol bekliyor'
            : state.syncing
            ? 'Kayıtlar eşitleniyor…'
            : state.pending.isNotEmpty
            ? '${state.pending.length} kayıt gönderilmeyi bekliyor'
            : 'Çevrimdışı • Masraf ve yakıt kaydı ekleyebilirsin');
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        onTap: () => context.push('/sync'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                state.online
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_off_outlined,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
