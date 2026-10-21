# 🗺️ TidyPics — Roadmap

> Mise à jour : 21/10/2026
> Le détail de chaque fonctionnalité (Fx) est dans le [cahier des charges](cahier-des-charges.md). La liste des tâches, case par case, est dans le [backlog](backlog.md).

## Où on en est

**La V1 est complète côté fonctionnalités** (lots 0 à 7) et tourne sur l'émulateur et sur un Pixel 10. **La V2 est faite** : doublons, succès, partage, captures d'écran, rappels façon jeu et documents. Restent les tests sur le Pixel, les finitions, puis l'APK pour les proches. iOS attend un iPhone.

| Étape | Contenu | État |
|---|---|---|
| Lot 0 — Socle | Organisation, direction artistique, logo, thèmes, CI, photos de test | ✅ (hors kanban GitHub) |
| Lot 0bis — Prototypes | Corbeille Android, « Gestion des médias », taille des lots, Google Photos | ✅ · 🔬 JPG + RAW sur iOS |
| Lot 1 — Galerie | Onboarding, permissions, base locale, scan (20 000 photos en ~3 s) | ✅ |
| Lot 2 — Swipe | Gestes, annuler, passer, favori, modes de tri, tablette, dossier d'origine | ✅ |
| Lot 3 — Suppression | Panier, récap, corbeille, vidage, envoi en quittant l'app | ✅ |
| Lot 4 — Stats | Espace libéré, barres, courbe, menu | ✅ |
| Lot 5 — Tri ciblé | Par année et par mois | ✅ |
| Lot 6 — Groupes | Rafales, paires JPG + RAW, tri des RAW | ✅ (rafales natives iOS à faire) |
| Lot 7 — Vidéos | Même fil que les photos, grosses vidéos en tête, lecture sans le son | ✅ · 🔬 fluidité sur le Pixel |
| Lot 8 — Tests sur appareils | Pixel 10 en cours ; iPhone et iPad sans appareil pour l'instant | 🟡 |
| **V2 — Lot 11 — Doublons** | Empreinte visuelle, écran « Doublons », rafales fiables | ✅ |
| V2 — Lot 13 — Succès et confort | Succès, partage et « ouvrir dans la galerie », mode captures d'écran, rappels | ✅ |
| V2 — Lot 12 — Documents | PDF, Word, téléchargements, sans permission spéciale | ✅ · 🔬 sur le Pixel |
| **Lot 9 — Finitions** | Accessibilité, textes, cas limites, « À propos » | ⏭️ **prochaine étape** |
| Lot 10 — APK pour les proches | Un APK propre à partager, avant toute publication sur les stores | ⏸️ plus tard |
| V3 | Tous les fichiers, IA sur le téléphone, nettoyage Google Photos (si Google le permet) | 💡 |

## Lot 8 — Tests sur appareils 🟡

**Pixel 10 : ce qu'on sait**
- ✅ Google Photos **garde la copie cloud** après une suppression dans TidyPics. C'est attendu : TidyPics ne supprime que le fichier du téléphone (voir V3).
- 🔬 Vidéos pas fluides. Piste la plus probable : l'app lancée depuis Android Studio tourne en mode debug, bien plus lent sur un téléphone. À refaire avec l'APK de release. Si ça rame encore : vidéos 4K ou HDR du Pixel, à creuser.

**Pixel 10 : reste à voir**
- 60 fps au swipe, paires JPG + RAW, rafales, « Gestion des médias », envoi en quittant l'app.
- Scan d'une vraie galerie : temps, place prise par la base, durée du calcul des empreintes.

**iPhone et iPad** : pas d'appareil pour l'instant. Les tests (JPG + RAW, rafales natives `burstIdentifier`, vidéos iCloud, accès limité, mise en page iPad) attendent qu'on en ait un.

## V2

### Lot 11 — Doublons ✅
- **Empreinte visuelle** de chaque photo, calculée sur le téléphone en tâche de fond ([ADR 0009](adr/0009-empreinte-visuelle.md)) : formes, détails et couleurs. Une copie WhatsApp recompressée garde la même empreinte, une autre photo non.
- **Écran « Doublons »** depuis le menu : la meilleure version est gardée (plus de pixels, moins compressée, hors dossier WhatsApp), un tap change d'avis, tout part à la corbeille en un seul lot.
- **Rafales fiables** : même dossier obligatoire, jamais dans un dossier de photos reçues (WhatsApp, Telegram, téléchargements, captures), et empreintes proches. Les photos WhatsApp reçues à la même heure ne forment plus une rafale.

### Lot 13 — Succès et confort ✅
- **Succès** : 16 succès. Paliers d'espace libéré (100 Mo à 20 Go), de photos triées (100 à 10 000), séries de jours d'affilée (3, 7, 30), et des premières fois (rafale triée, doublon supprimé, RAW trié, mois trié en entier, galerie entière). Un écran depuis le menu avec la série en cours, une annonce quand on en débloque un. Ceux déjà mérités avant la mise à jour sont inscrits sans annonce.
- **Appui long sur une carte** : « Partager… » (menu de partage du système : Google Photos, Drive, WhatsApp…, sans compte dans l'app) et « Ouvrir dans la galerie », pour retrouver la photo.
- **Captures d'écran** : un tri dédié depuis le menu, seulement les captures.
- **Rappels façon jeu** : le moment (8 h, 13 h, 19 h) choisi à l'onboarding, tous les jours tant qu'on revient puis de plus en plus espacés ; série, avancée, succès à portée, défi du jour ; « 30 photos cette semaine » une fois la galerie triée à 90 % ([ADR 0011](adr/0011-rappels-locaux.md)).
- **Doublons en grand et au swipe**, **barre d'avancée des vidéos**.

### Lot 12 — Documents ✅
- **Sans permission spéciale**, par le sélecteur du système : « Mes documents » (le dossier Documents donné une fois) et « Trier des fichiers » (n'importe où). Accepté par le Play Store, donc plus besoin d'en faire une exclusivité de l'APK ([ADR 0010](adr/0010-documents-sans-permission-speciale.md)).
- Aperçu : première page des PDF, début du texte des Word / PowerPoint / Excel, bouton « Ouvrir ».
- **Corbeille de TidyPics** (la corbeille du système refuse les documents, vérifié) : 30 jours, restauration, « Vider les documents ».
- À vérifier sur le Pixel : de vrais PDF (gros, protégés), la restauration.

## Lot 9 — Finitions ⏳

- **Accessibilité** : TalkBack et VoiceOver sur tout le parcours, grand texte système, contrastes.
- **Textes** : les stats disent « photos supprimées » même pour des vidéos ; relire l'anglais.
- **Cas limites** : galerie vide, permission retirée en cours de route, vidéo illisible, plus de place sur le téléphone.
- **Écran « À propos »** : version, rien n'est envoyé, licences des paquets.
- **Performance** : démarrage à froid sous 2 s, mémoire avec une galerie de 50 000 éléments.

## Lot 10 — APK pour les proches ⏸️

Avant les stores : un APK qu'on peut envoyer à ses proches.
- Une **clé de signature** à soi, gardée hors du dépôt : sans elle, impossible d'installer une mise à jour par-dessus.
- Un APK léger (un par type de processeur, ou un seul universel), un numéro de version qui monte à chaque envoi.
- Une page d'explication : autoriser l'installation d'apps inconnues, installer, mettre à jour.
- La publication sur le Play Store et l'App Store vient plus tard.

## V3 💡

- **Tous les types de fichiers**, au-delà des documents.
- **IA sur le téléphone**, sans réseau : photos floues, captures d'écran, meilleure photo d'une rafale proposée en premier.
- **Nettoyer Google Photos** : aujourd'hui **impossible pour une app tierce**. Google n'a jamais proposé de suppression dans son API, et depuis mars 2025 l'API ne donne plus accès qu'aux photos créées par l'app elle-même. Il faudrait aussi une connexion à un compte Google, contraire au « aucun compte » ([ADR 0001](adr/0001-app-100-pourcent-locale.md)). À surveiller ; en attendant, on peut au mieux guider l'utilisateur vers la corbeille de Google Photos.

## Décisions qui restent à prendre

| Sujet | Quand |
|---|---|

| Protéger `main` et créer le kanban GitHub, ou continuer sans | Avant le lot 10 |
| Compte développeur Apple (payant) pour tester sur iPhone | Quand un iPhone est disponible |
