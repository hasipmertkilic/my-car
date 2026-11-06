import 'package:flutter/material.dart';
import '../../../core/utils/turkish_plate.dart';

class TurkishLicensePlate extends StatelessWidget {
  const TurkishLicensePlate({super.key, required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) {
    final text = TurkishPlate.normalize(plate);
    return Semantics(
      label: 'Plaka $text',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF7),
              border: Border.all(color: const Color(0xFF20242A), width: 1.5),
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 23,
                      color: const Color(0xFF003399),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: const Text(
                        'TR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            text,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 19,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                              color: Color(0xFF101318),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
