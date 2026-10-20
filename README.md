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
flutter pub get        # dépendances + génération des traductions
flutter run            # lance l'app sur l'appareil connecté
```

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
