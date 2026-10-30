import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Crop the largest bright, low-colour paper region, retaining a margin.
/// Fall back to the full image when no convincing paper region is found.
Uint8List prepareReceiptImage(Uint8List bytes) {
  final source = img.decodeImage(bytes);
  if (source == null) return bytes;
  final decoded = img.bakeOrientation(source);
  final preview = img.copyResize(decoded, width: 200);
  final width = preview.width, height = preview.height;
  final visited = List<bool>.filled(width * height, false);
  bool paper(int index) {
    final p = preview.getPixel(index % width, index ~/ width);
    final maximum = math.max(p.r, math.max(p.g, p.b));
    final minimum = math.min(p.r, math.min(p.g, p.b));
    return (p.r + p.g + p.b) / 3 > 140 && maximum - minimum < 35;
  }

  var bestCount = 0, left = 0, top = 0, right = width - 1, bottom = height - 1;
  for (var start = 0; start < visited.length; start++) {
    if (visited[start] || !paper(start)) continue;
    final queue = <int>[start];
    visited[start] = true;
    var minX = width, minY = height, maxX = 0, maxY = 0;
    for (var offset = 0; offset < queue.length; offset++) {
      final index = queue[offset], x = index % width, y = index ~/ width;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      for (final next in [
        if (x > 0) index - 1,
        if (x + 1 < width) index + 1,
        if (y > 0) index - width,
        if (y + 1 < height) index + width,
      ]) {
        if (!visited[next]) {
          visited[next] = true;
          if (paper(next)) queue.add(next);
        }
      }
    }
    if (queue.length > bestCount &&
        maxX - minX > width * .3 &&
        maxY - minY > height * .4) {
      bestCount = queue.length;
      left = minX;
      right = maxX;
      top = minY;
      bottom = maxY;
    }
  }
  var image = decoded;
  if (bestCount > width * height * .12) {
    final sx = decoded.width / width, sy = decoded.height / height;
    final x = math.max(0, (left * sx - decoded.width * .03).floor());
    final y = math.max(0, (top * sy - decoded.height * .03).floor());
    final endX = math.min(
      decoded.width,
      ((right + 1) * sx + decoded.width * .03).ceil(),
    );
    final endY = math.min(
      decoded.height,
      ((bottom + 1) * sy + decoded.height * .03).ceil(),
    );
    image = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: endX - x,
      height: endY - y,
    );
  }
  final scale = math.min(1600 / image.width, 3200 / image.height);
  image = img.copyResize(
    image,
    width: (image.width * scale).round(),
    height: (image.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );
  image = img.grayscale(image);
  image = img.adjustColor(image, contrast: 1.2);
  // Focus the first pass on the usual product/payment band. The importer
  // retries the complete original if an amount or quantity is missing.
  image = img.copyCrop(
    image,
    x: 0,
    y: (image.height * .25).floor(),
    width: image.width,
    height: (image.height * .5).floor(),
  );
  return Uint8List.fromList(img.encodePng(image));
}
