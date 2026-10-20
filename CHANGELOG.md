# Changelog

Toutes les évolutions notables du projet sont listées ici.
Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Versions : [SemVer](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté
- Récap : pourcentage d'avancée pendant l'envoi à la corbeille.
- `tool/generate_bulk_photos.dart` : génère des milliers de petites photos pour les mesures.
- Tri des RAW : signale les RAW sans JPG gardé. Dans le tri normal, une paire JPG + RAW reste une seule carte ; badge RAW au récap.
- Rafales : flèche de retour au tri (la carte de la rafale garde ou supprime tout), explication à la première ouverture.
- Corbeille : nom du fichier affiché.
- Écrans choisis sur les maquettes :
  - Menu : courbe de l'espace libéré, barre de stockage du téléphone (part des photos), tuiles panier / par mois / JPG + RAW / corbeille.
  - Tri par mois : années en onglets, cartes avec photo et barre de complétion ; un mois propose toutes ses photos, même déjà vues.
  - Statistiques : total, barres par semaine ou par mois, cumul, chiffres clés.
  - Rafales : carte en éventail dans le tri, puis « Choisir les meilleures » photo par photo, avec bande de vignettes et récap avant de valider.
  - Doublons JPG + RAW : choix pour toutes les paires ou paire par paire, envoi groupé à la corbeille.
  - Tri des RAW au swipe, à part du JPG, ouvert depuis le menu, sur fond vert, avec sa propre explication. Le détail des paires s'ouvre depuis cet écran.
- Le tri propose les rafales et les paires JPG + RAW comme un seul élément.

### Corrigé
- Envoi de gros paniers bien plus rapide (3 000 photos : moins d'une minute au lieu de 4 sur émulateur) : miniatures lues 8 par 8.
- Des fichiers sans date de prise de vue copiés d'un coup ne forment plus des « rafales » géantes (50 photos au plus).
- Les paires JPG + RAW des Pixel (`….RAW-01.COVER.jpg` + `….RAW-02.ORIGINAL.dng`) étaient prises pour des rafales.
- Mode sombre : en-têtes en vert profond au lieu d'un aplat menthe éblouissant, fond noir autour des photos, surfaces mieux séparées du fond.
- Une miniature illisible (certains RAW) bloquait l'envoi à la corbeille.
- « En cours de suppression » sur Android : bouton « Vider maintenant » (effacement définitif, une popup ou aucune avec « Gestion des médias »), et journal aligné sur la vraie corbeille (photo restaurée ou effacée depuis l'app Galerie).
- Réglages : rafales (regroupement, écart de 1 à 10 s), envoi du panier en quittant l'app (Android 12+ avec « Gestion des médias » ; Android le termine au retour dans l'app), effacement sans corbeille (option avancée, avec avertissement).
- Logique prête pour les prochains écrans : rafales et paires JPG + RAW (`photo_groups.dart`), mois avec leur avancée, historique de l'espace libéré par semaine et par mois.
- Retours sur la première version :
  - L'app s'ouvre directement sur le tri. Le menu s'ouvre depuis une icône en haut à gauche.
  - Onboarding : tutoriel interactif avec trois photos d'exemple, animations à l'entrée des écrans.
  - En haut du tri : photos triées, pastille du panier et barre d'avancée vers le récap.
  - Récap toutes les 25 photos triées (réglable : 10, 25, 50, 100), seulement s'il y a des photos au panier.
  - Récap : un tap décoche une photo, qui reste visible et retourne dans le tri (ni supprimée ni gardée).
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
