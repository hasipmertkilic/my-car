import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/page_content.dart';
import '../controllers/activity_controller.dart';
import '../models/activity_record.dart';

class ActivityScope extends ConsumerWidget {
  const ActivityScope({
    super.key,
    required this.vehicleId,
    required this.builder,
  });
  final String vehicleId;
  final Widget Function(List<ActivityRecord> records) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(activityRecordsProvider(vehicleId))
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => PageContent(
          children: [
            const SectionTitle(
              'İşlem geçmişi yüklenemedi',
              subtitle: 'İnternet bağlantını kontrol edip tekrar dene.',
            ),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(activityRecordsProvider(vehicleId)),
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
}
