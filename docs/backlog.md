# Backlog V1

Liste des issues à créer sur GitHub : une milestone par lot, une case = une issue.
Les références Fx renvoient au [cahier des charges](cahier-des-charges.md).

## Lot 0 — Socle

- [x] Réorganiser le repo : docs, ADR, README, CONTRIBUTING, CHANGELOG
- [x] Direction artistique « Clean & zen »
- [x] Thèmes clair et sombre, police Manrope incluse
- [x] Squelette de l'app : Riverpod, go_router, traductions fr/en
- [x] CI : format, analyse, tests, build Android
- [x] Identifiant `com.azancoth.tidypics`, Android 11+ et iOS 15+
- [x] Logo : le « t » paysage
- [x] Icônes d'app (Android adaptative, iOS) et écran de démarrage (clair / sombre, Android 12+)
- [x] Monter Flutter en 3.47.7 (Riverpod 3, Gradle 9, AGP 9, modèles Android/iOS à jour), CI comprise
- [ ] Protéger `main` sur GitHub et créer le GitHub Project (kanban)

## Lot 0bis — Prototypes techniques

- [ ] Android : `createTrashRequest`, lecture de la corbeille (`QUERY_ARG_MATCH_TRASHED`), restauration, `createDeleteRequest`
- [ ] Android 12+ : « Gestion des médias » (`MANAGE_MEDIA`), vérifier l'absence de popup
- [ ] Mesurer la taille maximum d'un lot de suppression
- [ ] Google Photos : la copie cloud reste-t-elle après une suppression locale ?
- [ ] iOS : JPG + RAW, peut-on supprimer un seul des deux fichiers ?

## Lot 1 — Galerie

- [ ] F9 Onboarding en 3 écrans
- [ ] Permissions : Android (`READ_MEDIA_IMAGES`, accès partiel Android 14), iOS (complet ou limité), écran d'explication en cas de refus
- [ ] Base locale Drift : tables du §8.4, migrations (ADR 0006 à confirmer)
- [ ] Scan de la galerie en tâche de fond avec `photo_manager`, sur 20 000 photos
- [ ] Détection des nouvelles photos et des photos supprimées ailleurs

## Lot 2 — Swipe

- [ ] F1 Carte de swipe : gestes gauche, droite et haut, boutons équivalents, animations
- [ ] F1 Préchargement des photos suivantes, 60 fps
- [ ] F1 Annuler (10 dernières décisions), « Passer »
- [ ] F1 Favori système (Android `createFavoriteRequest`, iOS `isFavorite`)
- [ ] F2 Mode aléatoire (par défaut) et mode ordonné
- [ ] F1 Mise en page tablette (panneau latéral en paysage)

## Lot 3 — Suppression

- [ ] F3 Panier enregistré à chaque swipe
- [ ] F3 Checkpoint : seuil, « Je m'arrête là », sortie du tri, ouverture de l'app
- [ ] §6 Envoi groupé : Android (code natif) et iOS
- [ ] F3 Demande de « Gestion des médias » au premier checkpoint
- [ ] F3 Option Android 12+ : envoi automatique quand on quitte l'app
- [ ] F4 « En cours de suppression » : Android (corbeille réelle, restaurer, vider), iOS (journal, aide guidée)

## Lot 4 — Stats

- [ ] F7 Espace libéré depuis l'installation, par période, courbe
- [ ] F9 Accueil définitif : chiffre clé, progression, accès rapides

## Lot 5 — Tri ciblé

- [ ] F2 Navigation par année et par mois, avec la progression de chacun

## Lot 6 — Groupes

- [ ] F5 Rafales : regroupement (écart réglable, `burstIdentifier` iOS), carte de groupe, sélection
- [ ] F6 Paires JPG + RAW : détection, mode dédié, carte en session
- [ ] F8 Paramètres complets
