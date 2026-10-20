# 0002 — Suppression via la corbeille système

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
L'idée de départ était une corbeille gérée par l'app (30–40 jours). Mais garder les fichiers ne libère aucun espace pendant tout ce temps, et iOS comme Android 11+ ont déjà une corbeille d'environ 30 jours.

## Décision
- Les photos supprimées partent dans la **corbeille système** : `MediaStore.createTrashRequest` sur Android, `PHAssetChangeRequest.deleteAssets` sur iOS (album « Récemment supprimés »).
- Les suppressions sont **regroupées en lots** au checkpoint, pour n'avoir qu'une seule popup système par lot.
- Android 12+ : on propose la permission spéciale « Gestion des médias » (`MANAGE_MEDIA`) pour se passer de popup.
- Android : on peut lire, restaurer et vider la corbeille (code natif). iOS : un journal tenu par l'app et une aide pour vider « Récemment supprimés » à la main.

## Conséquences
- ✅ Aucune perte accidentelle, sans réinventer une corbeille.
- ✅ Avec iCloud, la suppression est synchronisée sur tous les appareils.
- ➖ iOS : impossible de lire, restaurer ou vider la corbeille depuis l'app.
- ➖ Il faut du code natif Kotlin pour la corbeille Android (`photo_manager` ne le fait pas).

Référence : https://developer.android.com/training/data-storage/shared/media
