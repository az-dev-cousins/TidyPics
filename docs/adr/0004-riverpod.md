# 0004 — Riverpod pour la gestion d'état

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
Deux candidats : Riverpod et Bloc. Le projet est mené par un développeur seul. L'essentiel de l'app affiche des données locales asynchrones (scan de la galerie, base de données). Seule la session de swipe a une logique vraiment complexe (annulation, panier, checkpoint).

## Décision
**Riverpod** (`flutter_riverpod`), sans génération de code pour commencer, avec `Notifier` et `AsyncNotifier`. Les repositories sont injectés via des providers.

## Conséquences
- ✅ Peu de code, `AsyncValue` (chargement / données / erreur) idéal pour la galerie.
- ✅ Injection des dépendances intégrée, tests faciles en remplaçant un provider.
- ➖ La session de swipe devra être un `Notifier` bien découpé et testé unitairement.
- ➖ Il faudra s'en tenir à une seule syntaxe (classes `Notifier`, sans `StateNotifier` ni les anciens providers).
