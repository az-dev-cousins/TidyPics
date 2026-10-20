import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tidypics/core/utils/formatters.dart';
import 'package:tidypics/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  test('tailles en français', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.fileSize(820000), '820 Ko');
    expect(fr.fileSize(3200000), '3,2 Mo');
    expect(fr.fileSize(12400000000), '12,4 Go');
    expect(fr.fileSize(30000000000), '30 Go');
  });

  test('tailles en anglais', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.fileSize(3200000), '3.2 MB');
  });

  test('date courte en majuscules', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.shortDate(DateTime(2019, 7, 14)), '14 JUIL. 2019');
  });
}
