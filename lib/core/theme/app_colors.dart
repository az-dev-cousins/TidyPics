import 'package:flutter/material.dart';

/// Palette « Clean & zen ».
///
/// Source de vérité : docs/design/direction-artistique.md.
abstract final class AppPalette {
  // Clair
  static const paper = Color(0xFFF6F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF22272B);
  static const inkMuted = Color(0xFF5C666D);
  static const line = Color(0xFFDAD7CC);
  static const mint = Color(0xFFBFE8D6);
  static const mintInk = Color(0xFF155C4B);
  static const fir = Color(0xFF1E7A64);
  static const tomato = Color(0xFFE04A32);
  static const sun = Color(0xFFFFC21A);
  static const sunOutline = Color(0xFFD99A00);

  // Sombre
  static const night = Color(0xFF121615);
  static const nightSurface = Color(0xFF1B2120);
  static const nightInk = Color(0xFFE8ECEA);
  static const nightInkMuted = Color(0xFF9AA5A1);
  static const nightLine = Color(0xFF33403C);
  static const nightMint = Color(0xFF1F3B33);
  static const brightMint = Color(0xFF6FD3B1);
  static const onBrightMint = Color(0xFF0E2A22);
  static const nightTomato = Color(0xFFFF7B63);
}

/// Couleurs propres à TidyPics, absentes du ColorScheme Material.
///
/// Les couleurs d'action (supprimer, garder, favori) sont toujours
/// accompagnées d'une icône : la couleur seule ne porte jamais l'information.
@immutable
class TidyColors extends ThemeExtension<TidyColors> {
  const TidyColors({
    required this.delete,
    required this.keep,
    required this.onKeep,
    required this.favorite,
    required this.favoriteOutline,
    required this.mint,
    required this.onMint,
    required this.inkMuted,
    required this.line,
  });

  final Color delete;
  final Color keep;
  final Color onKeep;

  /// Jaune réservé à l'étoile du favori, jamais en aplat.
  final Color favorite;
  final Color favoriteOutline;
  final Color mint;
  final Color onMint;
  final Color inkMuted;
  final Color line;

  static const light = TidyColors(
    delete: AppPalette.tomato,
    keep: AppPalette.fir,
    onKeep: AppPalette.surface,
    favorite: AppPalette.sun,
    favoriteOutline: AppPalette.sunOutline,
    mint: AppPalette.mint,
    onMint: AppPalette.mintInk,
    inkMuted: AppPalette.inkMuted,
    line: AppPalette.line,
  );

  static const dark = TidyColors(
    delete: AppPalette.nightTomato,
    keep: AppPalette.brightMint,
    onKeep: AppPalette.onBrightMint,
    favorite: AppPalette.sun,
    favoriteOutline: AppPalette.sun,
    mint: AppPalette.nightMint,
    onMint: AppPalette.mint,
    inkMuted: AppPalette.nightInkMuted,
    line: AppPalette.nightLine,
  );

  /// Raccourci : `TidyColors.of(context).delete`.
  static TidyColors of(BuildContext context) =>
      Theme.of(context).extension<TidyColors>()!;

  @override
  bool operator ==(Object other) =>
      other is TidyColors &&
      other.delete == delete &&
      other.keep == keep &&
      other.onKeep == onKeep &&
      other.favorite == favorite &&
      other.favoriteOutline == favoriteOutline &&
      other.mint == mint &&
      other.onMint == onMint &&
      other.inkMuted == inkMuted &&
      other.line == line;

  @override
  int get hashCode => Object.hash(
        delete,
        keep,
        onKeep,
        favorite,
        favoriteOutline,
        mint,
        onMint,
        inkMuted,
        line,
      );

  @override
  TidyColors copyWith({
    Color? delete,
    Color? keep,
    Color? onKeep,
    Color? favorite,
    Color? favoriteOutline,
    Color? mint,
    Color? onMint,
    Color? inkMuted,
    Color? line,
  }) {
    return TidyColors(
      delete: delete ?? this.delete,
      keep: keep ?? this.keep,
      onKeep: onKeep ?? this.onKeep,
      favorite: favorite ?? this.favorite,
      favoriteOutline: favoriteOutline ?? this.favoriteOutline,
      mint: mint ?? this.mint,
      onMint: onMint ?? this.onMint,
      inkMuted: inkMuted ?? this.inkMuted,
      line: line ?? this.line,
    );
  }

  @override
  TidyColors lerp(TidyColors? other, double t) {
    if (other == null) return this;
    return TidyColors(
      delete: Color.lerp(delete, other.delete, t)!,
      keep: Color.lerp(keep, other.keep, t)!,
      onKeep: Color.lerp(onKeep, other.onKeep, t)!,
      favorite: Color.lerp(favorite, other.favorite, t)!,
      favoriteOutline: Color.lerp(favoriteOutline, other.favoriteOutline, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      onMint: Color.lerp(onMint, other.onMint, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}
