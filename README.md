# TidyPics

**Trie tes photos et tes vidéos d'un swipe et libère de la place, sans que rien ne quitte ton téléphone.**

TidyPics est une app mobile Flutter (Android et iOS, téléphones et tablettes) pour faire le ménage dans sa galerie. Photos et vidéos défilent comme des cartes : ⬅️ supprimer, ➡️ garder, ⬆️ garder et mettre en favori. Les suppressions passent par la corbeille du système : rien n'est perdu par accident, et l'espace gagné est affiché à chaque étape.

- 🔒 100 % local : pas de compte, pas de serveur, aucune requête réseau
- 🎲 Tri aléatoire par défaut, ordonné ou ciblé par année et par mois
- 🎬 Vidéos dans le même tri, les plus grosses en premier, lecture sans le son
- 🧺 Panier et récap : une seule confirmation pour tout un lot, corbeille du système
- 📸 Rafales et paires JPG + RAW regroupées, tri des RAW à part
- 🪞 Doublons (copies WhatsApp, fichiers copiés) repérés sur le téléphone
- 🏆 Succès, tri des captures d'écran, partage, rappel facultatif
- 📊 Espace libéré, stockage du téléphone, stats par semaine et par mois
- 📱 Téléphones et tablettes, thème clair et sombre

> Statut : **V1 complète côté fonctionnalités**, testée sur l'émulateur et un Pixel 10. **V2 bien avancée** (doublons, succès, captures, partage, rappels). Voir la [roadmap](docs/roadmap.md).

## Documentation

| Document | Contenu |
|---|---|
| [Roadmap](docs/roadmap.md) | Où on en est, prochaines étapes, V2 et V3 |
| [Cahier des charges](docs/cahier-des-charges.md) | Périmètre, fonctionnalités, contraintes, découpage en lots |
| [Backlog](docs/backlog.md) | Les tâches, case par case |
| [Décisions d'architecture](docs/adr/README.md) | Le pourquoi des choix techniques |
| [Direction artistique](docs/design/direction-artistique.md) | Couleurs, typo, ton, logo |
| [Contribuer](CONTRIBUTING.md) | Branches, commits, PR, qualité |
| [Changelog](CHANGELOG.md) | Historique des versions |

## Démarrer

Prérequis : Flutter 3.47 stable (Dart 3.13), Android SDK (API 30+) et/ou Xcode avec CocoaPods (iOS 15+).

```bash
flutter pub get                    # dépendances + génération des traductions
flutter emulators --launch Pixel_7 # ou ouvre un simulateur iOS : open -a Simulator
flutter run                        # lance l'app sur l'émulateur démarré
```

> TidyPics ne cible que **Android et iOS**. Dans ton IDE, choisis l'émulateur ou le simulateur comme appareil cible, pas « macOS » ni « Chrome » : ces cibles ne sont pas configurées et donnent l'erreur *No macOS desktop project configured*.

## Photos et vidéos de test

Un émulateur neuf n'a aucune photo. Des scripts créent une fausse galerie qui couvre les cas de l'app : 150 photos de 2019 à 2026, 5 rafales, 4 paires JPG + RAW, 12 captures d'écran et 3 doublons.

```bash
make photos-android        # les envoie sur l'émulateur Android démarré
make photos-android-clean  # les retire de l'émulateur
make photos-ios            # les ajoute au simulateur iOS démarré
make videos-android        # 3 petites vidéos, filmées sur l'émulateur (pas besoin de ffmpeg)
make videos-android-big    # idem + une vidéo de ~120 Mo, qui passe en tête du tri
make videos-android-clean  # retire les vidéos de test
```

`make` seul liste tous les raccourcis. Derrière, ce sont `tool/seed_test_photos.sh` et `dart run tool/generate_test_photos.dart` (génère les photos dans `build/test_photos`).

- Le script d'envoi génère les photos s'il ne les trouve pas.
- Les JPEG portent leur date de prise de vue (EXIF) : la galerie les classe à la bonne date.
- Les captures d'écran (PNG) n'ont pas de date de prise de vue, comme les vraies.
- Les faux RAW (`.DNG`) sont des TIFF : reconnus par Android, ignorés sur iOS.
- iOS ne permet pas de supprimer les photos du simulateur en ligne de commande : on passe par l'app Photos ou par `xcrun simctl erase`.
- Pour les mesures de performance : `dart run tool/generate_bulk_photos.dart <dossier> 20000` génère 20 000 petites photos datées. En mode profile (`flutter run --profile`), l'app affiche dans les logs la durée du scan et de la préparation du tri.
- L'émulateur a peu de place : si l'installation échoue (`INSTALL_FAILED_INSUFFICIENT_STORAGE`), désinstalle TidyPics de l'émulateur puis relance.

## Vérifier avant de pousser

```bash
make check   # dart format, flutter analyze, flutter test
```

La CI GitHub Actions lance ces mêmes commandes, plus un build Android, à chaque push sur `main`.

## Stack

Flutter · Riverpod · go_router · Drift (SQLite) · photo_manager · video_player · image (empreintes visuelles) · share_plus · flutter_local_notifications · Material 3 · Manrope (incluse dans l'app)

Un peu de code natif : Kotlin (`MainActivity.kt`, corbeille, tailles, stockage) et Swift (`AppDelegate.swift`, stockage).

Le code de la base (`lib/data/sources/local_db.g.dart`) est généré et versionné. Après une modification de `local_db.dart`, relance `dart run build_runner build`.

## Structure

```plaintext
lib/
├── main.dart        # point d'entrée
├── app/             # MaterialApp, routes
├── core/            # thèmes clair / sombre, formatage (tailles, dates)
├── data/            # modèles, base Drift, accès galerie, repositories
├── l10n/            # traductions (fr par défaut, en)
├── features/        # onboarding, home (menu), swipe (tri, rafales), months, cart (récap),
│                    # trash, raw_pairs, duplicates, achievements, reminders,
│                    # stats, settings, gallery
└── shared/widgets/  # widgets réutilisables (miniatures…)
docs/                # roadmap, cahier des charges, backlog, ADR, design
tool/                # photos et vidéos de test, mesures
```
