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
  // « Autre » dans la barre de stockage : neutre, toujours légendé.
  static const stone = Color(0xFF9E998C);
  // « Vidéos » dans la barre de stockage, à côté du sapin des photos.
  static const violet = Color(0xFF7A63C2);

  // Fond derrière une photo (bandes au-dessus et en dessous).
  static const photoBackdrop = Color(0xFFEFEEE8);

  // Sombre
  static const night = Color(0xFF101413);
  static const nightSurface = Color(0xFF1A2221);
  static const nightInk = Color(0xFFE8ECEA);
  static const nightInkMuted = Color(0xFF9AA5A1);
  static const nightLine = Color(0xFF2E3B37);
  static const nightMint = Color(0xFF1F3B33);
  static const brightMint = Color(0xFF6FD3B1);
  static const onBrightMint = Color(0xFF0E2A22);
  static const nightTomato = Color(0xFFFF7B63);
  static const nightStone = Color(0xFF7F8C87);
  static const nightViolet = Color(0xFF9580E0);
  // Carte d'en-tête (espace libéré) en sombre : vert profond, pas d'aplat vif.
  static const nightHero = Color(0xFF173A30);
  static const nightPhotoBackdrop = Color(0xFF0B0F0E);

  // Mode RAW : fond vert, reconnaissable en clair comme en sombre.
  static const rawFir = Color(0xFF1E7A64);
  static const nightRawFir = Color(0xFF145243);
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
    required this.chartNeutral,
    required this.chartVideo,
    required this.hero,
    required this.onHero,
    required this.photoBackdrop,
    required this.rawBackdrop,
    required this.onRawBackdrop,
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

  /// Catégorie « Autre » des graphiques (ex. stockage hors photos).
  final Color chartNeutral;

  /// Catégorie « Vidéos » des graphiques.
  final Color chartVideo;

  /// Fond de la carte d'en-tête (espace libéré) et son texte.
  final Color hero;
  final Color onHero;

  /// Fond derrière une photo, dans les cartes.
  final Color photoBackdrop;

  /// Fond du tri des RAW et son texte.
  final Color rawBackdrop;
  final Color onRawBackdrop;

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
    chartNeutral: AppPalette.stone,
    chartVideo: AppPalette.violet,
    hero: AppPalette.fir,
    onHero: AppPalette.surface,
    photoBackdrop: AppPalette.photoBackdrop,
    rawBackdrop: AppPalette.rawFir,
    onRawBackdrop: AppPalette.surface,
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
    chartNeutral: AppPalette.nightStone,
    chartVideo: AppPalette.nightViolet,
    hero: AppPalette.nightHero,
    onHero: AppPalette.mint,
    photoBackdrop: AppPalette.nightPhotoBackdrop,
    rawBackdrop: AppPalette.nightRawFir,
    onRawBackdrop: AppPalette.nightInk,
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
      other.line == line &&
      other.chartNeutral == chartNeutral &&
      other.chartVideo == chartVideo &&
      other.hero == hero &&
      other.onHero == onHero &&
      other.photoBackdrop == photoBackdrop &&
      other.rawBackdrop == rawBackdrop &&
      other.onRawBackdrop == onRawBackdrop;

  @override
  int get hashCode => Object.hashAll([
    delete,
    keep,
    onKeep,
    favorite,
    favoriteOutline,
    mint,
    onMint,
    inkMuted,
    line,
    chartNeutral,
    chartVideo,
    hero,
    onHero,
    photoBackdrop,
    rawBackdrop,
    onRawBackdrop,
  ]);

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
    Color? chartNeutral,
    Color? chartVideo,
    Color? hero,
    Color? onHero,
    Color? photoBackdrop,
    Color? rawBackdrop,
    Color? onRawBackdrop,
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
      chartNeutral: chartNeutral ?? this.chartNeutral,
      chartVideo: chartVideo ?? this.chartVideo,
      hero: hero ?? this.hero,
      onHero: onHero ?? this.onHero,
      photoBackdrop: photoBackdrop ?? this.photoBackdrop,
      rawBackdrop: rawBackdrop ?? this.rawBackdrop,
      onRawBackdrop: onRawBackdrop ?? this.onRawBackdrop,
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
      chartNeutral: Color.lerp(chartNeutral, other.chartNeutral, t)!,
      chartVideo: Color.lerp(chartVideo, other.chartVideo, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      photoBackdrop: Color.lerp(photoBackdrop, other.photoBackdrop, t)!,
      rawBackdrop: Color.lerp(rawBackdrop, other.rawBackdrop, t)!,
      onRawBackdrop: Color.lerp(onRawBackdrop, other.onRawBackdrop, t)!,
    );
  }
}
