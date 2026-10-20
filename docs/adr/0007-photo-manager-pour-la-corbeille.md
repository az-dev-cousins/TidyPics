# 0007 — `photo_manager` pour la corbeille et « Gestion des médias »

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
Le cahier des charges (§8.1) prévoyait du code natif Kotlin pour tout ce que `photo_manager` ne savait pas faire : envoyer à la corbeille, restaurer, gérer « Gestion des médias ». Depuis la version 3.12, `photo_manager` le fait :
- `moveToTrash` et `restoreFromTrash` (Android 11+, via `createTrashRequest`) ;
- `canManageMedia` et `requestManageMedia` (Android 12+) ;
- `favoriteAsset` (favori système, Android et iOS) ;
- `fileSize` (taille du fichier sans le lire en entier).

## Décision
- On passe par `photo_manager` pour toutes ces opérations, derrière l'interface `GallerySource` (`lib/data/sources/gallery_source.dart`).
- Le seul code natif est un canal `tidypics/device` qui donne la version d'Android (pour savoir si « Gestion des médias » existe).
- Les gros paniers sont découpés en lots de 500 photos. La vraie limite reste à mesurer (lot 0bis).

## Conséquences
- ✅ Très peu de code natif à maintenir, même API sur Android et iOS.
- ✅ Les tests remplacent `GallerySource` par une fausse galerie.
- ➖ `photo_manager` ne sait pas **lire** la corbeille Android ni la **vider** (`createDeleteRequest`). « En cours de suppression » s'appuie donc sur le journal tenu par l'app, et « Vider maintenant » demandera du Kotlin plus tard.
