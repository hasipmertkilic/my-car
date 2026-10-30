import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/parking_place.dart';
import '../services/parking_location.dart';

class NavigateToCarButton extends ConsumerStatefulWidget {
  const NavigateToCarButton({
    super.key,
    required this.place,
    this.label = 'Aracıma git',
  });
  final ParkingPlace place;
  final String label;
  @override
  ConsumerState<NavigateToCarButton> createState() =>
      _NavigateToCarButtonState();
}

class _NavigateToCarButtonState extends ConsumerState<NavigateToCarButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              final opened = await ref
                  .read(parkingLocationProvider)
                  .navigateToCar(widget.place);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Rota açılamadı. Google Haritalar’ı kontrol edip tekrar dene.',
                    ),
                  ),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rota açılamadı. Tekrar dene.')),
                );
              }
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    icon: const Icon(Icons.directions_walk),
    label: Text(busy ? 'Haritalar açılıyor…' : widget.label),
  );
}
