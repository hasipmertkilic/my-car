import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/core/utils/turkish_plate.dart';
import 'package:my_car/features/vehicles/widgets/turkish_license_plate.dart';

void main() {
  test('standard groups, province range and letters are validated', () {
    for (final plate in [
      '01 A 1234',
      '81 Z 12345',
      '34 AB 123',
      '06 CD 1234',
      '35 ABC 12',
      '34 ABC 123',
      '34abc123',
    ]) {
      expect(TurkishPlate.validate(plate), isNull, reason: plate);
    }
    for (final plate in [
      '',
      '00 AB 123',
      '82 AB 123',
      '99 ABC 123',
      '1 AB 123',
      '34 ABCD 12',
      '34 AB 12',
      '34 ABC 1234',
      '34 A 123',
      '34 A 123456',
      '34 QW 123',
      '34 ÇA 123',
      '34 AB 000',
      'hello',
      '34-ABC-123',
      '34 AB 123!',
    ]) {
      expect(TurkishPlate.validate(plate), isNotNull, reason: plate);
    }
    expect(TurkishPlate.normalize(' 34abc123 '), '34 ABC 123');
    expect(TurkishPlate.normalize('06  ab   1234'), '06 AB 1234');
  });
  test('typing and paste format groups while keeping deletion editable', () {
    const formatter = TurkishPlateInputFormatter();
    TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    expect(
      formatter.formatEditUpdate(value(''), value('34abc123')).text,
      '34 ABC 123',
    );
    expect(formatter.formatEditUpdate(value('34'), value('34a')).text, '34 A');
    expect(
      formatter.formatEditUpdate(value('34 AB'), value('34 AB1')).text,
      '34 AB 1',
    );
    expect(
      formatter.formatEditUpdate(value('34 AB'), value('34AB')).text,
      '34AB',
    );
    expect(formatter.formatEditUpdate(value('34'), value('34💥')).text, '34');
    expect(
      formatter
          .formatEditUpdate(value('34 AB 1'), value('34 AB 12'))
          .selection
          .extentOffset,
      8,
    );
  });
  testWidgets('plate badge fits narrow layouts and large text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 130,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: TurkishLicensePlate(plate: '34abc123'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('34 ABC 123'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
