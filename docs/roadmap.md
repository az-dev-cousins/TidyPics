# 🗺️ TidyPics — Roadmap

> Mise à jour : 20/10/2026
> Le détail de chaque fonctionnalité (Fx) est dans le [cahier des charges](cahier-des-charges.md). La liste des tâches, case par case, est dans le [backlog](backlog.md).

## Où on en est

**La V1 est complète côté fonctionnalités** (lots 0 à 7) et tourne sur l'émulateur Android. Il reste à la valider sur de vrais téléphones (Pixel 10, iPhone), à la finir, puis à la publier.

| Étape | Contenu | État |
|---|---|---|
| Lot 0 — Socle | Organisation, direction artistique, logo, thèmes, CI, photos de test | ✅ (hors kanban GitHub) |
| Lot 0bis — Prototypes | Corbeille Android, « Gestion des médias », taille des lots | ✅ émulateur · 🔬 2 tests sur appareil |
| Lot 1 — Galerie | Onboarding, permissions, base locale, scan (20 000 photos en ~3 s) | ✅ |
| Lot 2 — Swipe | Gestes, annuler, passer, favori, modes de tri, tablette | ✅ (60 fps à mesurer sur appareil) |
| Lot 3 — Suppression | Panier, récap, corbeille, vidage, envoi en quittant l'app | ✅ |
| Lot 4 — Stats | Espace libéré, barres, courbe, menu | ✅ |
| Lot 5 — Tri ciblé | Par année et par mois | ✅ |
| Lot 6 — Groupes | Rafales, paires JPG + RAW, tri des RAW | ✅ (rafales natives iOS à faire) |
| Lot 7 — Vidéos | Même fil que les photos, grosses vidéos en tête, lecture sans le son | ✅ |
| **Lot 8 — Tests sur appareils** | Pixel 10, iPhone, iPad | ⏭️ **prochaine étape** |
| Lot 9 — Finitions V1 | Accessibilité, textes, cas limites, écran « À propos » | ⏳ |
| Lot 10 — Publication V1 | Play Store, App Store, politique de confidentialité | ⏳ |
| V2 | Doublons exacts, succès, rappels, partage vers le cloud | 💡 |
| V3 | Tous les fichiers, IA sur le téléphone | 💡 |

## Lot 8 — Tests sur appareils ⏭️

Ce que l'émulateur ne peut pas dire. Chaque point se règle par un test, puis une correction si besoin.

**Android (Pixel 10)**
- Fluidité : 60 fps au swipe, vidéos fluides (l'émulateur décode sans carte graphique : il rame, un vrai téléphone non).
- Google Photos : la copie cloud reste-t-elle après une suppression dans TidyPics ? La réponse change le texte du récap.
- Paires JPG + RAW du Pixel, rafales, « Gestion des médias » et envoi en quittant l'app.
- Grosse galerie réelle : temps du scan, place prise par la base.

**iOS (iPhone, puis iPad)**
- JPG + RAW : un import forme souvent un seul élément à deux fichiers. Peut-on n'en supprimer qu'un ? Sinon, le tri des RAW reste réservé à Android.
- Rafales natives (`burstIdentifier`) : les reconnaître en plus de l'écart de temps.
- Vidéos dans iCloud : temps avant lecture, et taille inconnue (la durée sert alors de repère).
- Accès limité à la photothèque, popup de suppression, « Récemment supprimés ».
- iPad : mise en page tablette, en portrait et en paysage.

## Lot 9 — Finitions V1 ⏳

- **Accessibilité** : TalkBack et VoiceOver sur tout le parcours, grand texte système, contrastes.
- **Textes** : les stats disent « photos supprimées » même pour des vidéos ; relire l'anglais.
- **Cas limites** : galerie vide, permission retirée en cours de route, carte mémoire retirée, vidéo illisible, plus de place sur le téléphone.
- **Écran « À propos »** : version, rien n'est envoyé, licences des paquets, lien vers la politique de confidentialité.
- **Performance** : démarrage à froid sous 2 s, mémoire avec une galerie de 50 000 éléments.
- Vérifier l'icône et l'écran de démarrage sur les deux systèmes.

## Lot 10 — Publication V1 ⏳

- **Android** : clé de signature de publication, build `appbundle`, fiche Play Store (textes, captures téléphone et tablette), formulaire « Sécurité des données » (aucune donnée collectée), test fermé avant la production.
- **iOS** : compte développeur Apple (99 $/an), TestFlight, fiche App Store, « App Privacy » (aucune donnée collectée).
- **Politique de confidentialité** : une page courte (« aucune donnée ne quitte le téléphone »), hébergée hors de l'app.
- Version `1.0.0`, `CHANGELOG.md` à jour, tag Git.

## V2 💡

- **Doublons exacts** : même photo enregistrée deux fois (WhatsApp, captures renvoyées). Détection par empreinte calculée sur le téléphone.
- **Succès** : paliers d'espace libéré, séries de jours de tri.
- **Rappels** : notification locale facultative (« 200 nouvelles photos à trier »). Demande la permission de notification.
- **Partage vers le cloud** : appui long sur un favori → menu de partage du système (Google Photos, Drive…), sans compte dans l'app.
- Captures d'écran : un mode dédié, comme le tri des RAW.

## V3 💡

- **Tous les types de fichiers** : documents, téléchargements, fichiers lourds.
- **IA sur le téléphone**, sans réseau : photos floues, captures d'écran, meilleure photo d'une rafale proposée en premier.

## Décisions qui restent à prendre

| Sujet | Quand |
|---|---|
| Protéger `main` et créer le kanban GitHub, ou continuer sans | Avant la publication |
| Compte développeur Apple (payant) | Lot 10 |
| Ordre de la V2 | Après la publication |
