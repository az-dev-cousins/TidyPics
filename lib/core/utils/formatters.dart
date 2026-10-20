import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Formatage des tailles et des dates, selon la langue de l'app.
extension Formatters on AppLocalizations {
  /// « 3,2 Mo », « 1,4 Go », « 820 Ko » (base 1000, comme les téléphones).
  String fileSize(int bytes) {
    final number = NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: 1,
    );
    if (bytes >= 1000 * 1000 * 1000) {
      return sizeGb(number.format(bytes / 1e9));
    }
    if (bytes >= 1000 * 1000) {
      return sizeMb(number.format(bytes / 1e6));
    }
    final kb = NumberFormat.decimalPatternDigits(
      locale: localeName,
      decimalDigits: 0,
    );
    return sizeKb(kb.format(bytes / 1e3));
  }

  /// « 14 JUIL. 2019 », style « Label » de la direction artistique.
  String shortDate(DateTime date) =>
      DateFormat.yMMMd(localeName).format(date).toUpperCase();
}
