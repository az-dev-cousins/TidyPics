import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Formatage des tailles et des dates, selon la langue de l'app.
extension Formatters on AppLocalizations {
  /// « 3,2 Mo », « 1,4 Go », « 820 Ko » (base 1000, comme les téléphones).
  String fileSize(int bytes) {
    // Une décimale, sauf si elle vaut zéro : « 30 Go », « 3,2 Mo ».
    String number(double value) {
      final rounded = (value * 10).round() / 10;
      return NumberFormat.decimalPatternDigits(
        locale: localeName,
        decimalDigits: rounded == rounded.truncate() ? 0 : 1,
      ).format(rounded);
    }

    if (bytes >= 1000 * 1000 * 1000) {
      return sizeGb(number(bytes / 1e9));
    }
    if (bytes >= 1000 * 1000) {
      return sizeMb(number(bytes / 1e6));
    }
    final kb = NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: 0,
    );
    return sizeKb(kb.format(bytes / 1e3));
  }

  /// Durée d'une vidéo : « 0:42 », « 12:05 », « 1:02:03 ».
  String videoLength(Duration duration) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  /// « 14 JUIL. 2019 », style « Label » de la direction artistique.
  String shortDate(DateTime date) =>
      DateFormat.yMMMd(localeName).format(date).toUpperCase();

  /// « Mars 2025 », avec une majuscule.
  String monthName(DateTime date) {
    final text = DateFormat.yMMMM(localeName).format(date);
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  /// « Mars », avec une majuscule.
  String monthShort(DateTime date) {
    final text = DateFormat.MMMM(localeName).format(date);
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }
}
