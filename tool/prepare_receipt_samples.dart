import 'dart:io';
import 'package:my_car/features/records/services/receipt_image_preprocessing.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 3) {
    throw ArgumentError('Yerel fiş örnekleri klasörünü belirt.');
  }
  final count = args.length > 1 ? int.parse(args[1]) : 3;
  final output = Directory(
    args.length > 2 ? args[2] : 'build/receipt-validation',
  );
  await output.create(recursive: true);
  for (var i = 1; i <= count; i++) {
    final bytes = await File('${args.first}/$i.jpg').readAsBytes();
    await File(
      '${output.path}/$i.png',
    ).writeAsBytes(prepareReceiptImage(bytes));
  }
  stdout.writeln('$count yerel örnek OCR için hazırlandı.');
}
