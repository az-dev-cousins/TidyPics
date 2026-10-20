import 'gallery_photo.dart';
import 'photo_groups.dart';
import 'visual_hash.dart';

/// Photos en double (F11) : la même image enregistrée plusieurs fois
/// (copie WhatsApp, capture renvoyée, photo retouchée puis réenregistrée).
class DuplicateGroup {
  DuplicateGroup(List<GalleryPhoto> photos)
    : photos = [...photos]..sort(_better);

  /// La meilleure d'abord : c'est celle qu'on propose de garder.
  final List<GalleryPhoto> photos;

  GalleryPhoto get best => photos.first;

  /// Identifiant stable : la meilleure photo.
  String get id => best.id;

  /// Ce qu'on libère en ne gardant que la meilleure.
  int get extraBytes =>
      photos.skip(1).fold(0, (sum, p) => sum + (p.sizeBytes ?? 0));
}

/// Plus de pixels, puis un fichier plus lourd (moins compressé), puis hors
/// d'un dossier de photos reçues, puis la plus ancienne (l'originale).
int _better(GalleryPhoto a, GalleryPhoto b) {
  final pixels = (b.width * b.height).compareTo(a.width * a.height);
  if (pixels != 0) return pixels;
  final size = (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
  if (size != 0) return size;
  final received = (isReceivedFolder(a.folder) ? 1 : 0).compareTo(
    isReceivedFolder(b.folder) ? 1 : 0,
  );
  if (received != 0) return received;
  return a.takenAt.compareTo(b.takenAt);
}

/// Groupes de photos presque identiques : au plus
/// [VisualHash.duplicateDistance] bits d'écart entre empreintes.
///
/// Ne sont pas des doublons : les vidéos, les RAW (traités par F6), les
/// images trop unies et deux photos d'une même rafale (même dossier, moins
/// de [burstGap] d'écart).
///
/// Pour éviter de comparer chaque photo à toutes les autres, l'empreinte est
/// coupée en 5 morceaux : deux empreintes à 4 bits ou moins d'écart ont
/// forcément un morceau identique. On ne compare que ces candidates.
List<DuplicateGroup> findDuplicates(
  List<GalleryPhoto> photos, {
  Duration burstGap = const Duration(seconds: 3),
}) {
  final candidates = [
    for (final p in photos)
      if (!p.isVideo &&
          !p.isRaw &&
          p.visualColor != null &&
          p.visualDetail != null &&
          VisualHash.isInformative(p.visualHash))
        p,
  ];
  const bands = [(0, 13), (13, 13), (26, 13), (39, 13), (52, 12)];
  final buckets = <(int, int), List<int>>{};
  for (final (i, photo) in candidates.indexed) {
    final hash = photo.visualHash!;
    for (final (b, (start, length)) in bands.indexed) {
      final key = (b, (hash >>> start) & ((1 << length) - 1));
      (buckets[key] ??= []).add(i);
    }
  }

  // Union-find : un groupe réunit tout ce qui est relié de proche en proche.
  final parent = List<int>.generate(candidates.length, (i) => i);
  int root(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  for (final members in buckets.values) {
    // Un morceau partagé par des centaines de photos ne dit rien (ciel,
    // fond sombre) : on l'ignore plutôt que tout comparer.
    if (members.length > 400) continue;
    for (var x = 0; x < members.length; x++) {
      for (var y = x + 1; y < members.length; y++) {
        final a = candidates[members[x]];
        final b = candidates[members[y]];
        if (!_samePhoto(a, b)) continue;
        // Deux photos d'une rafale se ressemblent sans être des doublons.
        // Une copie exacte, elle, a la même date : on la garde.
        final sameBurst =
            a.folder == b.folder &&
            a.takenAt.difference(b.takenAt).abs() <= burstGap;
        if (sameBurst && !_identical(a, b)) continue;
        parent[root(members[x])] = root(members[y]);
      }
    }
  }

  final groups = <int, List<GalleryPhoto>>{};
  for (final (i, photo) in candidates.indexed) {
    (groups[root(i)] ??= []).add(photo);
  }
  final result = <DuplicateGroup>[];
  for (final members in groups.values) {
    if (members.length < 2) continue;
    // Pas de proche en proche : chaque photo doit ressembler à la meilleure,
    // pas seulement à une voisine.
    final best = DuplicateGroup(members).best;
    final close = [
      for (final p in members)
        if (p == best || _samePhoto(p, best)) p,
    ];
    if (close.length > 1) result.add(DuplicateGroup(close));
  }
  return result..sort((a, b) => b.extraBytes.compareTo(a.extraBytes));
}

/// Mêmes proportions, mêmes formes, mêmes détails et mêmes couleurs : la
/// même photo.
bool _samePhoto(GalleryPhoto a, GalleryPhoto b) =>
    _sameShape(a, b) &&
    VisualHash.distance(a.visualHash!, b.visualHash!) <=
        VisualHash.duplicateDistance &&
    VisualHash.sameColors(a.visualColor!, b.visualColor!) &&
    VisualHash.detailDistanceOf(a.visualDetail!, b.visualDetail!) <=
        VisualHash.detailDistance;

/// Même fichier enregistré deux fois : même taille au pixel près et
/// empreintes identiques.
bool _identical(GalleryPhoto a, GalleryPhoto b) =>
    a.width == b.width &&
    a.height == b.height &&
    a.sizeBytes == b.sizeBytes &&
    a.visualHash == b.visualHash &&
    VisualHash.detailDistanceOf(a.visualDetail!, b.visualDetail!) <= 2;

/// Une copie garde les proportions de l'original (à 2 % près). Dimensions
/// inconnues : on ne peut pas dire, on laisse passer.
bool _sameShape(GalleryPhoto a, GalleryPhoto b) {
  if (a.width <= 0 || a.height <= 0 || b.width <= 0 || b.height <= 0) {
    return true;
  }
  final ra = a.width / a.height;
  final rb = b.width / b.height;
  return (ra - rb).abs() <= 0.02 * ra;
}
