# Décisions d'architecture (ADR)

Une fiche courte par décision importante : **pourquoi** on a choisi ça, pour ne pas refaire le débat dans six mois.

## Règles
- Une décision = un fichier `NNNN-titre-court.md`, numéroté dans l'ordre.
- Statuts : `Proposée` → `Acceptée` → (éventuellement) `Remplacée par NNNN`.
- On ne réécrit pas une ADR acceptée : on en crée une nouvelle qui la remplace.

## Modèle

```markdown
# NNNN — Titre

- Statut : Proposée | Acceptée | Remplacée par NNNN
- Date : AAAA-MM-JJ

## Contexte
Le problème et les contraintes.

## Décision
Ce qu'on fait.

## Conséquences
Ce que ça implique, en bien et en moins bien.
```

## Index

| # | Décision | Statut |
|---|---|---|
| 0001 | [App 100 % locale, sans compte](0001-app-100-pourcent-locale.md) | Acceptée |
| 0002 | [Suppression via la corbeille système](0002-suppression-via-corbeille-systeme.md) | Acceptée |
| 0003 | [Android 11 minimum](0003-android-11-minimum.md) | Acceptée |
| 0004 | [Riverpod pour la gestion d'état](0004-riverpod.md) | Acceptée |
| 0005 | [Navigation avec go_router](0005-go-router.md) | Acceptée |
| 0006 | [Stockage local avec Drift](0006-drift.md) | Acceptée |
| 0007 | [`photo_manager` pour la corbeille et « Gestion des médias »](0007-photo-manager-pour-la-corbeille.md) | Acceptée |
| 0008 | [`video_player` pour lire les vidéos](0008-video-player.md) | Acceptée |
| 0009 | [Empreinte visuelle calculée sur le téléphone](0009-empreinte-visuelle.md) | Acceptée |
| 0010 | [Documents par le sélecteur du système, corbeille de TidyPics](0010-documents-sans-permission-speciale.md) | Acceptée |
| 0011 | [Rappels façon jeu, programmés sur le téléphone](0011-rappels-locaux.md) | Acceptée |
