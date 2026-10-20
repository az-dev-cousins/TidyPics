import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Thèmes clair et sombre de TidyPics (direction « Clean & zen »).
abstract final class AppTheme {
  static const fontFamily = 'Manrope';

  /// Rayons utilisés dans toute l'app.
  static const radiusThumbnail = 14.0;
  static const radiusCard = 18.0;
  static const radiusSwipeCard = 28.0;

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.fir,
      onPrimary: AppPalette.surface,
      primaryContainer: AppPalette.mint,
      onPrimaryContainer: AppPalette.mintInk,
      secondary: AppPalette.mintInk,
      onSecondary: AppPalette.surface,
      tertiary: AppPalette.sun,
      onTertiary: AppPalette.ink,
      error: AppPalette.tomato,
      onError: AppPalette.surface,
      surface: AppPalette.paper,
      onSurface: AppPalette.ink,
      onSurfaceVariant: AppPalette.inkMuted,
      surfaceContainerLowest: AppPalette.surface,
      surfaceContainerLow: AppPalette.surface,
      surfaceContainer: AppPalette.surface,
      outline: AppPalette.line,
      outlineVariant: AppPalette.line,
    ),
    tidy: TidyColors.light,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppPalette.brightMint,
      onPrimary: AppPalette.onBrightMint,
      primaryContainer: AppPalette.nightMint,
      onPrimaryContainer: AppPalette.mint,
      secondary: AppPalette.mint,
      onSecondary: AppPalette.onBrightMint,
      tertiary: AppPalette.sun,
      onTertiary: AppPalette.night,
      error: AppPalette.nightTomato,
      onError: AppPalette.night,
      surface: AppPalette.night,
      onSurface: AppPalette.nightInk,
      onSurfaceVariant: AppPalette.nightInkMuted,
      surfaceContainerLowest: AppPalette.nightSurface,
      surfaceContainerLow: AppPalette.nightSurface,
      surfaceContainer: AppPalette.nightSurface,
      outline: AppPalette.nightLine,
      outlineVariant: AppPalette.nightLine,
    ),
    tidy: TidyColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required TidyColors tidy,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    final text = base.textTheme;
    final textTheme = text.copyWith(
      // Display : les gros chiffres (« 12,4 Go libérés »).
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      // Titres d'écran et de section.
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      // Corps de texte.
      bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
      // Labels (dates, tailles, boutons).
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: text.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    const pill = StadiumBorder();
    const buttonMinSize = Size(64, 48);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [tidy],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: tidy.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pill,
          minimumSize: buttonMinSize,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pill,
          minimumSize: buttonMinSize,
          side: BorderSide(color: tidy.line),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pill,
          minimumSize: buttonMinSize,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(color: tidy.line, thickness: 1),
    );
  }
}
