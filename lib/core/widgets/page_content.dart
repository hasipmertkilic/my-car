import 'package:flutter/material.dart';

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(
    this.title, {
    super.key,
    required this.eyebrow,
    this.subtitle,
  });
  final String title, eyebrow;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: t.textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              color: c.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: t.textTheme.headlineLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: t.textTheme.bodyMedium?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void showNextStage(BuildContext context, String feature) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(feature),
    content: const Text(
      'Bu özellik sonraki geliştirme aşamasında eklenecek. Şu anda örnek verilerle arayüzü inceleyebilirsin.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tamam'),
      ),
    ],
  ),
);
