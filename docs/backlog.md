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
- [x] Photos de test pour émulateur et simulateur (dates, rafales, JPG + RAW, captures, doublons)
- [ ] Protéger `main` sur GitHub et créer le GitHub Project (kanban)

## Lot 0bis — Prototypes techniques

- [x] Android : `createTrashRequest` et restauration (via `photo_manager`, [ADR 0007](adr/0007-photo-manager-pour-la-corbeille.md))
- [x] Android : lecture de la corbeille (`QUERY_ARG_MATCH_TRASHED`) et vidage (`createDeleteRequest`), en Kotlin
- [x] Android 12+ : « Gestion des médias » (`MANAGE_MEDIA`) : vérifié sur l'émulateur Android 16, aucune popup à l'envoi en corbeille
- [x] Mesurer la taille maximum d'un lot de suppression (émulateur : 3 000 photos en un lot sans erreur ; lots de 3 000 sans « Gestion des médias », de 250 avec, pour la barre d'avancée)
- [ ] Google Photos : la copie cloud reste-t-elle après une suppression locale ?
- [ ] iOS : JPG + RAW, peut-on supprimer un seul des deux fichiers ?

## Lot 1 — Galerie

- [x] F9 Onboarding en 3 écrans
- [x] Permissions : Android (`READ_MEDIA_IMAGES`, accès partiel Android 14), iOS (complet ou limité), écran d'explication en cas de refus
- [x] Base locale Drift : tables du §8.4, migrations (ADR 0006 confirmée)
- [x] Scan de la galerie avec `photo_manager`
- [x] Mesurer le scan sur 20 000 photos (émulateur, mode profile : ~3,2 s en arrière-plan ; file de tri prête en 0,6 s)
- [x] Détection des nouvelles photos et des photos supprimées ailleurs

## Lot 2 — Swipe

- [x] F1 Carte de swipe : gestes gauche, droite et haut, boutons équivalents, animations
- [x] F1 Préchargement de la photo suivante
- [ ] F1 Vérifier les 60 fps sur un appareil milieu de gamme
- [x] F1 Annuler (10 dernières décisions), « Passer »
- [x] F1 Favori système (Android `createFavoriteRequest`, iOS `isFavorite`)
- [x] F2 Mode aléatoire (par défaut) et mode ordonné
- [x] F1 Mise en page tablette (panneau latéral en paysage, à partir de 840 × 480 points)

## Lot 3 — Suppression

- [x] F3 Panier enregistré à chaque swipe
- [x] F3 Checkpoint : seuil, « Je m'arrête là », sortie du tri, ouverture de l'app
- [x] §6 Envoi groupé : Android et iOS
- [x] F3 Demande de « Gestion des médias » au premier checkpoint
- [x] F3 Option Android 12+ : envoi automatique quand on quitte l'app (Android le termine au retour dans l'app)
- [x] F4 « En cours de suppression » : journal, jours restants, restaurer (Android), aide guidée (iOS)
- [x] F4 Android : lire la vraie corbeille et « Vider maintenant »

## Choix de design

Pistes et choix : https://claude.ai/artifact/D4jveh5gf2pPxWirwQxVsC. Menu A + C, Par mois A + C, Stats A + B, Rafales A, JPG + RAW A : faits.

## Lot 4 — Stats

- [x] F7 Espace libéré depuis l'installation, par période, courbe
- [x] F9 Accueil définitif : chiffre clé, progression, accès rapides

## Lot 5 — Tri ciblé

- [x] F2 Navigation par année et par mois, avec la progression de chacun

## Lot 6 — Groupes

- [x] F5 Rafales : regroupement (écart réglable), carte de groupe, sélection
- [ ] F5 iOS : reconnaître les rafales natives (`burstIdentifier`)
- [x] F6 Paires JPG + RAW : détection, mode dédié, carte en session
- [x] F8 Paramètres complets
