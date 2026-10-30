import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

Future<void> main(List<String> args) async {
  final source = File('assets/branding/app_icon.png');
  if (args.isNotEmpty) {
    await source.parent.create(recursive: true);
    await File(args.single).copy(source.path);
  }
  final original = img.decodeImage(await source.readAsBytes());
  if (original == null || original.width != original.height) {
    throw StateError('Kare bir uygulama simgesi gerekli.');
  }
  Future<void> png(String path, img.Image image) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(img.encodePng(image));
    final verified = img.decodePng(await file.readAsBytes())!;
    if (verified.width != image.width || verified.height != image.height) {
      throw StateError('Simge boyutu doğrulanamadı: $path');
    }
  }

  img.Image scaled(int size) => img.copyResize(
    original,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  const densities = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final entry in densities.entries) {
    final folder = 'android/app/src/main/res/mipmap-${entry.key}';
    await png('$folder/ic_launcher.png', scaled(entry.value));
    // Android adaptive icons use a 108 dp layer with a central safe region.
    final canvasSize = (entry.value * 108 / 48).round();
    final artSize = (canvasSize * 72 / 108).round();
    final canvas = img.Image(
      width: canvasSize,
      height: canvasSize,
      numChannels: 4,
    );
    img.compositeImage(
      canvas,
      scaled(artSize),
      dstX: (canvasSize - artSize) ~/ 2,
      dstY: (canvasSize - artSize) ~/ 2,
    );
    await png('$folder/ic_launcher_foreground.png', canvas);
  }
  for (final size in [192, 512]) {
    await png('web/icons/Icon-$size.png', scaled(size));
    final maskable = img.Image(width: size, height: size, numChannels: 3);
    final background = original.getPixel(0, 0);
    img.fill(
      maskable,
      color: img.ColorRgb8(
        background.r.toInt(),
        background.g.toInt(),
        background.b.toInt(),
      ),
    );
    final artSize = (size * .8).round();
    img.compositeImage(
      maskable,
      scaled(artSize),
      dstX: (size - artSize) ~/ 2,
      dstY: (size - artSize) ~/ 2,
    );
    await png('web/icons/Icon-maskable-$size.png', maskable);
  }
  await png('web/favicon.png', scaled(64));
  const iosFolder = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final catalog =
      jsonDecode(await File('$iosFolder/Contents.json').readAsString()) as Map;
  final written = <String>{};
  for (final entry in catalog['images'] as List) {
    final name = entry['filename'] as String?;
    if (name == null || !written.add(name)) continue;
    final points = double.parse((entry['size'] as String).split('x').first);
    final scale = double.parse((entry['scale'] as String).replaceAll('x', ''));
    await png(
      '$iosFolder/$name',
      scaled((points * scale).round()).convert(numChannels: 3),
    );
  }
  stdout.writeln(
    'Android, iOS ve web simgeleri oluşturuldu; boyutları doğrulandı.',
  );
}

