# Changelog

Toutes les évolutions notables du projet sont listées ici.
Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Versions : [SemVer](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- **Première version utilisable** (lots 1 à 3, version courte) :
  - Onboarding en 3 écrans, demande d'accès aux photos, écran d'explication en cas de refus, bandeau en accès limité.
  - Indexation de la galerie dans une base locale Drift, mise à jour quand des photos sont prises ou supprimées ailleurs et au retour dans l'app.
  - Tri par swipe : gauche (panier), droite (garder), haut (garder + favori système), boutons équivalents et flèches du clavier, « Passer », annulation des 10 dernières décisions, préchargement de la photo suivante, badge RAW.
  - Panier enregistré à chaque swipe et checkpoint : au seuil (50 par défaut), avec « Je m'arrête là », en quittant le tri et à l'ouverture de l'app s'il reste des photos en attente. Un tap retire une photo du panier.
  - Envoi groupé à la corbeille système : une seule popup par lot sur Android, aucune avec « Gestion des médias » (proposée au premier checkpoint sur Android 12+).
  - « En cours de suppression » : jours restants, restauration sur Android, aide pour vider « Récemment supprimés » sur iOS.
  - Accueil : espace libéré depuis l'installation, progression du tri, panier, réglages (ordre du tri, seuil du checkpoint, thème, « Gestion des médias », reproposer les photos gardées).
- `Makefile` : raccourcis pour les photos de test (`make photos-android`…) et les vérifications (`make check`).
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
