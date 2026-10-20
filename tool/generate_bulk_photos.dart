// Génère beaucoup de petites photos datées, pour mesurer le scan et la
// suppression en masse sur un émulateur (ex. 20 000 photos).
//
// Usage : dart run tool/generate_bulk_photos.dart <dossier> [nombre]
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final out = Directory(args.isNotEmpty ? args[0] : 'build/bulk_photos')
    ..createSync(recursive: true);
  final count = args.length > 1 ? int.parse(args[1]) : 20000;
  final start = DateTime(2018);
  String two(int v) => v.toString().padLeft(2, '0');
  for (var i = 0; i < count; i++) {
    // Sept minutes d'écart : pas de rafale géante.
    final date = start.add(Duration(minutes: i * 7));
    final image = img.Image(width: 48, height: 36)
      ..clear(img.ColorRgb8(40 + i % 200, 120, 200 - i % 150));
    final exif =
        '${date.year}:${two(date.month)}:${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
    image.exif.imageIfd['DateTime'] = exif;
    image.exif.exifIfd['DateTimeOriginal'] = exif;
    final name =
        'BULK_${date.year}${two(date.month)}${two(date.day)}_'
        '${two(date.hour)}${two(date.minute)}_$i.jpg';
    File('${out.path}/$name')
        .writeAsBytesSync(img.encodeJpg(image, quality: 60));
  }
  stdout.writeln('$count photos dans ${out.path}');
}
