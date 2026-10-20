# 0006 — Stockage local avec Drift

- Statut : Proposée (à confirmer au lot 1)
- Date : 2026-10-20

## Contexte
Il faut stocker durablement et interroger des dizaines de milliers de lignes : décisions par photo, panier, journal de suppression, groupes (rafales, JPG+RAW) et événements de statistiques.

## Décision
- **Drift** (SQLite typé, requêtes réactives en `Stream`, migrations) pour les données métier.
- `shared_preferences` pour les réglages simples.

## Conséquences
- ✅ Requêtes SQL rapides (ex. « photos non triées de mars 2021 »), flux réactifs faciles à brancher sur Riverpod.
- ✅ Migrations versionnées.
- ➖ Il faut de la génération de code (`build_runner`).
