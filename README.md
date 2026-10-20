# TidyPics

**Trie tes photos d'un swipe et libère de la place, sans que rien ne quitte ton téléphone.**

TidyPics est une app mobile Flutter (Android et iOS, téléphones et tablettes) pour faire le ménage dans sa galerie. Les photos défilent comme des cartes : ⬅️ supprimer, ➡️ garder, ⬆️ garder et mettre en favori. Les suppressions passent par la corbeille du système : rien n'est perdu par accident, et l'espace gagné est affiché à chaque étape.

- 🔒 100 % local : pas de compte, pas de serveur, aucune requête réseau
- 🎲 Tri aléatoire par défaut, ordonné ou ciblé par année et par mois
- 🧺 Panier et checkpoint : une seule confirmation pour tout un lot
- 📸 Rafales et doublons JPG + RAW regroupés
- 📊 Espace libéré depuis l'installation

> Statut : **lot 0 (socle)** en cours. L'app n'est pas encore utilisable.

## Documentation

| Document | Contenu |
|---|---|
| [Cahier des charges](docs/cahier-des-charges.md) | Périmètre, fonctionnalités, contraintes, découpage en lots |
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

## Photos de test

Un émulateur neuf n'a aucune photo. Deux scripts créent une fausse galerie qui couvre les cas de l'app : 150 photos de 2019 à 2026, 5 rafales, 4 paires JPG + RAW, 12 captures d'écran et 3 doublons.

```bash
make photos-android        # les envoie sur l'émulateur Android démarré
make photos-android-clean  # les retire de l'émulateur
make photos-ios            # les ajoute au simulateur iOS démarré
```

`make` seul liste tous les raccourcis. Derrière, ce sont `tool/seed_test_photos.sh` et `dart run tool/generate_test_photos.dart` (génère les photos dans `build/test_photos`).

- Le script d'envoi génère les photos s'il ne les trouve pas.
- Les JPEG portent leur date de prise de vue (EXIF) : la galerie les classe à la bonne date.
- Les captures d'écran (PNG) n'ont pas de date de prise de vue, comme les vraies.
- Les faux RAW (`.DNG`) sont des TIFF : reconnus par Android, ignorés sur iOS.
- iOS ne permet pas de supprimer les photos du simulateur en ligne de commande : on passe par l'app Photos ou par `xcrun simctl erase`.

## Vérifier avant de pousser

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

La CI GitHub Actions lance ces mêmes commandes sur chaque PR.

## Stack

Flutter · Riverpod · go_router · Material 3 · Manrope (incluse dans l'app)

## Structure

```plaintext
lib/
├── main.dart        # point d'entrée
├── app/             # MaterialApp, routes
├── core/theme/      # couleurs et thèmes clair / sombre
├── l10n/            # traductions (fr par défaut, en)
├── features/        # un dossier par fonctionnalité
└── shared/widgets/  # widgets réutilisables
docs/                # cahier des charges, ADR, design
```
