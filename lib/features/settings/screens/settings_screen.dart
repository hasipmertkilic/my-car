import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/page_content.dart';
import '../controllers/theme_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/app_user.dart';
import '../../vehicles/controllers/vehicle_controller.dart';
import '../../inspection/widgets/notification_preferences.dart';
import '../../inspection/services/reminder_manager.dart';
import '../../maintenance/maintenance_notification_preferences.dart';
import '../../maintenance/maintenance_reminders.dart';

Future<void> signOut(BuildContext context, WidgetRef ref) async {
  try {
    final maintenance = ref.read(maintenanceReminderManagerProvider);
    final inspections = ref.read(reminderManagerProvider);
    await ref.read(authRepositoryProvider).signOut();
    maintenance.synchronize(null, []);
    inspections.synchronize(null, []);
    await Future.wait([maintenance.settled, inspections.settled]);
    if (context.mounted) {
      ref.invalidate(activeVehicleProvider);
      ref.invalidate(themeModeProvider);
    }
  } on AuthFailure catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çıkış yapılamadı. Tekrar dene.')),
      );
    }
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool busy = false;

  Future<void> resetPassword(String email) async {
    if (busy || email.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifreni yenile'),
        content: Text(
          '$email adresine şifre sıfırlama bağlantısı gönderilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bağlantı gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Şifre sıfırlama bağlantısı gönderildi. Gelen kutunu ve spam klasörünü kontrol et.',
            ),
          ),
        );
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı gönderilemedi. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmSignOut() async {
    if (busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabından çıkış yapılsın mı?'),
        content: const Text(
          'Tekrar kullanmak için giriş yapman gerekecek. Hesabına kaydedilmiş araç ve geçmiş kayıtların korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busy) return;
    setState(() => busy = true);
    await signOut(context, ref);
    if (mounted) setState(() => busy = false);
  }

  void showDataInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Verilerin ve konumun'),
      content: const SingleChildScrollView(
        child: Text(
          'Araç, yakıt, masraf, bakım, poliçe ve park kayıtların Firebase hesabına bağlı olarak saklanır.\n\n'
          'Park konumu ve yakındaki istasyonlar için konum izni, ilgili düğmeye bastığında istenir. İstasyon ararken konum Google Places servisine gönderilir.\n\n'
          'Yakıt fişi ve poliçe belgeleri, alanları doldurmak için cihaz üzerinde okunur. Kaydetmeden önce sonuçları kontrol edebilirsin.\n\n'
          'Yol tarifi Google Haritalar’da açılır.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final email = ref.watch(authSessionProvider).user?.email ?? '';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget heading(String title, IconData icon, String subtitle) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/summary'),
        ),
        title: const Text('Ayarlar'),
      ),
      body: PageContent(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withValues(alpha: .17),
                    colors.surface,
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: colors.primary,
                    child: Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: colors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hesabım',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SelectableText(
                          email.isEmpty ? 'Hesap bilgisi yükleniyor…' : email,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          heading(
            'Görünüm',
            Icons.palette_outlined,
            'Sana uygun görünümü seç.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ThemeMode>(
                    key: ValueKey(mode),
                    initialValue: mode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Uygulama teması',
                      prefixIcon: Icon(Icons.contrast_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('Sistem ayarı'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Açık tema'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Koyu tema'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(themeModeProvider.notifier).setMode(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sistem ayarı, telefonunun açık veya koyu görünümünü izler. Tema tercihin bu uygulama oturumunda geçerlidir.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          heading(
            'Bildirimler',
            Icons.notifications_none_rounded,
            'Yaklaşan muayene ve bakımları zamanında hatırla.',
          ),
          const NotificationPreferences(),
          const SizedBox(height: 10),
          const MaintenanceNotificationPreferences(),
          heading(
            'Hesap ve güvenlik',
            Icons.lock_outline_rounded,
            'Şifreni yönet, oturumunu kontrol et.',
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('Şifremi yenile'),
                  subtitle: const Text(
                    'E-posta adresine sıfırlama bağlantısı gönder',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy || email.isEmpty
                      ? null
                      : () => resetPassword(email),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Verilerim ve konumum'),
                  subtitle: const Text('Bilgilerin nasıl kullanıldığını öğren'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: showDataInfo,
                ),
                if (busy) const LinearProgressIndicator(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : confirmSignOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: .5)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Çıkış yap'),
          ),
          heading(
            'Uygulama hakkında',
            Icons.info_outline_rounded,
            'Aracına dair her şey bir arada.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_filled,
                        color: colors.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'My Car',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '0.2.26',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Araç ve kilometre takibi, yakıt ve masraflar, bakım geçmişi ve takibi, muayene hatırlatmaları, sigorta ve kasko poliçeleri, park geçmişi ve yakındaki istasyonlar.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Üniversite bitirme projesi kapsamında geliştirilmiştir.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
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




