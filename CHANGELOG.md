# Changelog

Toutes les évolutions notables du projet sont listées ici.
Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Versions : [SemVer](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Photos de test : générateur (`tool/generate_test_photos.dart`) et envoi sur émulateur Android ou simulateur iOS (`tool/seed_test_photos.sh`).
- Logo « t » paysage, icônes d'app Android (adaptative) et iOS, écran de démarrage clair et sombre.
- Cahier des charges V1, décisions d'architecture (ADR 0001 à 0006) et direction artistique « Clean & zen ».
- Thèmes clair et sombre, police Manrope incluse dans l'app.
- Squelette de l'app : Riverpod, go_router, traductions fr/en, page d'accueil provisoire.
- CI GitHub Actions : format, analyse, tests, build Android.
- Modèles d'issues et de PR, guide de contribution.

### Modifié
- Flutter 3.47.7 (Dart 3.13), Riverpod 3, go_router 18. Android passe en Kotlin DSL avec Gradle 9.3 et AGP 9.1 (compatible avec le Java 25 d'Android Studio). iOS adopte le modèle à scènes et Swift Package Manager.
- Identifiant de l'app : `com.azancoth.tidypics`. Android 11 minimum, iOS 15 minimum.

### Supprimé
- Code du template Flutter et anciennes notes `dev_docs/` (la formation Flutter est archivée dans `docs/archive/`).
