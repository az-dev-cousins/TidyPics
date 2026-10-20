# 0005 — Navigation avec go_router

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
L'app aura une dizaine d'écrans (onboarding, accueil, tri, année/mois, checkpoint, corbeille, JPG+RAW, stats, paramètres) et des redirections (pas de permission, donc l'écran d'explication).

## Décision
`go_router`, le package de navigation maintenu par l'équipe Flutter. Les routes sont déclarées dans `lib/app/router.dart`.

## Conséquences
- ✅ Les routes sont nommées et centralisées, et les redirections sont déclaratives (permissions, onboarding).
- ✅ Les liens profonds sont possibles plus tard (ex. une notification qui ouvre le checkpoint).
- ➖ Une dépendance de plus, légère.
