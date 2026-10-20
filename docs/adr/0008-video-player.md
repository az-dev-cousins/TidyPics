# 0008 — `video_player` pour lire les vidéos

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
Les vidéos arrivent dans le tri (F10) : il faut les lire sur la carte, sans le son au départ, avec pause et son. L'app ne fait aucune requête réseau ([ADR 0001](0001-app-100-pourcent-locale.md)).

## Décision
On utilise `video_player`, le paquet officiel de l'équipe Flutter (ExoPlayer sur Android, AVPlayer sur iOS).
- Seuls des fichiers locaux sont lus : `photo_manager` donne le fichier de la vidéo (`AssetEntity.file`).
- Le paquet ne demande aucune permission Android (pas d'accès Internet).
- Un seul lecteur à la fois : la carte du dessus. La suivante montre sa miniature.

## Conséquences
- Pas de code natif à écrire pour la lecture.
- Sur iOS, `AssetEntity.file` copie parfois la vidéo dans un dossier temporaire (vidéo dans iCloud ou au format HEVC) : le départ peut être plus lent. À vérifier sur un vrai iPhone.
- `media_kit` ou `better_player` font plus, mais ajoutent des binaires lourds pour un besoin simple.
