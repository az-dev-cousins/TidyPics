# TidyPics — consignes pour Claude

- Langue : français pour les échanges, les docs, les commentaires et les messages de commit.
- Source de vérité produit : `docs/cahier-des-charges.md`. Les décisions : `docs/adr/`. Le design : `docs/design/direction-artistique.md`.
- `docs/archive/` contient de vieilles notes : ne pas s'y fier.
- Conventions de code, branches et commits : voir `CONTRIBUTING.md`.
- Principe non négociable : l'app ne fait **aucune requête réseau** (pas de Firebase, pas d'analytics, pas de `google_fonts` au runtime).
- Vérifier avant de rendre la main : `dart format lib test && flutter analyze && flutter test`.
- Flutter 3.47.7 (Dart 3.13), Riverpod 3, Gradle 9 / AGP 9 en Kotlin DSL.
