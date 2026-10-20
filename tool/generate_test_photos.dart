// Génère un jeu de fausses photos pour tester TidyPics sur émulateur.
//
// Usage : dart run tool/generate_test_photos.dart [dossier] [--count N]
// Par défaut : build/test_photos, 150 photos « normales ».
//
// Chaque scénario du cahier des charges est couvert :
// - photos réparties de 2019 à 2026 (tri ordonné, tri par année / mois) ;
// - rafales : photos prises à 1 s d'intervalle (F5) ;
// - paires JPG + RAW, même nom et même date (F6) ;
// - captures d'écran (futur filtre IA) ;
// - doublons exacts.
//
// Les JPEG portent leur date de prise de vue dans les métadonnées EXIF :
// la galerie les classe donc à la bonne date. Le générateur est
// déterministe : il produit toujours les mêmes photos.
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

Future<void> main(List<String> args) async {
  var outPath = 'build/test_photos';
  var count = 150;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--count' && i + 1 < args.length) {
      count = int.parse(args[++i]);
    } else {
      outPath = args[i];
    }
  }

  final outDir = Directory(outPath);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  outDir.createSync(recursive: true);

  final generator = _Generator(outDir, Random(42));
  final normal = generator.normalPhotos(count);
  final bursts = generator.bursts(5);
  final rawPairs = generator.rawPairs(4);
  final screenshots = generator.screenshots(12);
  final duplicates = generator.duplicates(normal.take(3).toList());

  stdout.writeln('Photos générées dans ${outDir.path} :');
  stdout.writeln('  ${normal.length} photos normales');
  stdout.writeln('  ${bursts.length} photos en 5 rafales');
  stdout.writeln('  ${rawPairs.length} fichiers en paires JPG + RAW');
  stdout.writeln('  ${screenshots.length} captures d\'écran');
  stdout.writeln('  ${duplicates.length} doublons exacts');
}

class _Generator {
  _Generator(this.outDir, this.random);

  final Directory outDir;
  final Random random;
  var _serial = 0;

  static final _start = DateTime(2019);
  static final _end = DateTime(2026, 9, 30);

  /// Photos isolées, à des dates aléatoires entre 2019 et 2026.
  List<File> normalPhotos(int count) {
    final files = <File>[];
    for (var i = 0; i < count; i++) {
      final date = _randomDate();
      final portrait = random.nextBool();
      final image = _scene(
        width: portrait ? 750 : 1000,
        height: portrait ? 1000 : 750,
        hue: random.nextDouble(),
        lines: ['Photo #${++_serial}', _label(date)],
      );
      files.add(_writeJpg(image, 'IMG_${_stamp(date)}.jpg', date));
    }
    return files;
  }

  /// Rafales de 3 à 6 photos prises à 1 seconde d'intervalle.
  List<File> bursts(int burstCount) {
    final files = <File>[];
    for (var b = 1; b <= burstCount; b++) {
      final start = _randomDate();
      final size = 3 + random.nextInt(4);
      final hue = random.nextDouble();
      for (var i = 0; i < size; i++) {
        final date = start.add(Duration(seconds: i));
        final image = _scene(
          width: 1000,
          height: 750,
          hue: hue,
          // Le soleil se décale un peu d'une photo à l'autre.
          sunShift: i * 40,
          lines: ['Rafale $b - ${i + 1}/$size', _label(date)],
        );
        files.add(
          _writeJpg(
            image,
            'IMG_${_stamp(date)}_BURST${i.toString().padLeft(3, '0')}.jpg',
            date,
          ),
        );
      }
    }
    return files;
  }

  /// Paires JPG + RAW : même nom de fichier, même date.
  ///
  /// Le « RAW » est un TIFF avec l'extension .dng : la galerie le range
  /// comme une image, ce qui suffit pour tester le regroupement.
  List<File> rawPairs(int pairCount) {
    final files = <File>[];
    for (var p = 1; p <= pairCount; p++) {
      final date = _randomDate();
      final name = 'DSC_${9000 + p}';
      final image = _scene(
        width: 1000,
        height: 750,
        hue: random.nextDouble(),
        lines: ['Paire JPG + RAW $p', _label(date)],
      );
      files.add(_writeJpg(image, '$name.JPG', date));
      final raw = File('${outDir.path}/$name.DNG')
        ..writeAsBytesSync(img.encodeTiff(image));
      raw.setLastModifiedSync(date);
      files.add(raw);
    }
    return files;
  }

  /// Captures d'écran au format téléphone (PNG, sans EXIF).
  List<File> screenshots(int count) {
    final files = <File>[];
    for (var i = 1; i <= count; i++) {
      final date = _randomDate();
      final image = img.Image(width: 540, height: 1200);
      img.fill(image, color: img.ColorRgb8(246, 245, 240));
      img.fillRect(
        image,
        x1: 0,
        y1: 0,
        x2: 540,
        y2: 90,
        color: img.ColorRgb8(34, 39, 43),
      );
      for (var row = 0; row < 8; row++) {
        img.fillRect(
          image,
          x1: 30,
          y1: 140 + row * 120,
          x2: 510,
          y2: 220 + row * 120,
          color: img.ColorRgb8(220, 217, 205),
        );
      }
      img.drawString(
        image,
        'Capture $i',
        font: img.arial24,
        x: 30,
        y: 30,
        color: img.ColorRgb8(255, 255, 255),
      );
      final file = File('${outDir.path}/Screenshot_${_stamp(date)}.png')
        ..writeAsBytesSync(img.encodePng(image));
      file.setLastModifiedSync(date);
      files.add(file);
    }
    return files;
  }

  /// Copies exactes de photos existantes, sous un autre nom.
  List<File> duplicates(List<File> sources) {
    final files = <File>[];
    for (final (i, source) in sources.indexed) {
      final copy = File('${outDir.path}/IMG_copie_${i + 1}.jpg');
      source.copySync(copy.path);
      copy.setLastModifiedSync(source.lastModifiedSync());
      files.add(copy);
    }
    return files;
  }

  img.Image _scene({
    required int width,
    required int height,
    required double hue,
    required List<String> lines,
    int sunShift = 0,
  }) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: _hsv(hue, 0.35, 0.85));
    img.fillCircle(
      image,
      x: (width * 0.72).round() + sunShift,
      y: (height * 0.25).round(),
      radius: (width * 0.08).round(),
      color: img.ColorRgb8(255, 236, 170),
    );
    img.fillCircle(
      image,
      x: (width * 0.3).round(),
      y: height + (height * 0.35).round(),
      radius: (width * 0.75).round(),
      color: _hsv(hue, 0.55, 0.55),
    );
    for (final (i, line) in lines.indexed) {
      img.drawString(
        image,
        line,
        font: img.arial48,
        x: 40,
        y: 40 + i * 64,
        color: img.ColorRgb8(255, 255, 255),
      );
    }
    return image;
  }

  File _writeJpg(img.Image image, String name, DateTime date) {
    final exifDate = _exifDate(date);
    image.exif.imageIfd['DateTime'] = exifDate;
    image.exif.exifIfd['DateTimeOriginal'] = exifDate;
    image.exif.exifIfd['DateTimeDigitized'] = exifDate;
    final file = File('${outDir.path}/$name')
      ..writeAsBytesSync(img.encodeJpg(image, quality: 80));
    file.setLastModifiedSync(date);
    return file;
  }

  DateTime _randomDate() {
    final span = _end.difference(_start).inMinutes;
    final date = _start.add(Duration(minutes: random.nextInt(span)));
    // Des heures plausibles : entre 8 h et 21 h.
    return DateTime(
      date.year,
      date.month,
      date.day,
      8 + random.nextInt(14),
      random.nextInt(60),
      random.nextInt(60),
    );
  }

  static img.Color _hsv(double h, double s, double v) {
    final i = (h * 6).floor();
    final f = h * 6 - i;
    final p = v * (1 - s);
    final q = v * (1 - f * s);
    final t = v * (1 - (1 - f) * s);
    final (r, g, b) = switch (i % 6) {
      0 => (v, t, p),
      1 => (q, v, p),
      2 => (p, v, t),
      3 => (p, q, v),
      4 => (t, p, v),
      _ => (v, p, q),
    };
    return img.ColorRgb8(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}_'
      '${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';

  static String _exifDate(DateTime d) =>
      '${d.year}:${_two(d.month)}:${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  static String _label(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year} '
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
}
