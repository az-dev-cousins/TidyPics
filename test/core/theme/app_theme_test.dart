import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidypics/core/theme/app_colors.dart';
import 'package:tidypics/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('le thème clair expose les couleurs TidyPics claires', () {
      final theme = AppTheme.light;

      expect(theme.brightness, Brightness.light);
      expect(theme.extension<TidyColors>(), TidyColors.light);
      expect(theme.colorScheme.primary, AppPalette.fir);
      expect(theme.scaffoldBackgroundColor, AppPalette.paper);
    });

    test('le thème sombre expose les couleurs TidyPics sombres', () {
      final theme = AppTheme.dark;

      expect(theme.brightness, Brightness.dark);
      expect(theme.extension<TidyColors>(), TidyColors.dark);
      expect(theme.colorScheme.primary, AppPalette.brightMint);
      expect(theme.scaffoldBackgroundColor, AppPalette.night);
    });

    test('les deux thèmes utilisent Manrope', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
      }
    });
  });

  group('TidyColors', () {
    test('supprimer et garder ont des couleurs distinctes', () {
      for (final colors in [TidyColors.light, TidyColors.dark]) {
        expect(colors.delete, isNot(colors.keep));
        expect(colors.keep, isNot(colors.favorite));
      }
    });

    test('lerp aux bornes renvoie les palettes de départ et d\'arrivée', () {
      expect(TidyColors.light.lerp(TidyColors.dark, 0), TidyColors.light);
      expect(TidyColors.light.lerp(TidyColors.dark, 1), TidyColors.dark);
    });
  });
}
