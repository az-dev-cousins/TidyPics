# Contribuer à TidyPics

## Environnement

- Flutter **3.47.7** stable (la version épinglée dans la CI). Toute montée de version se fait dans une PR dédiée qui met aussi la CI à jour.
- Avant chaque PR :
  ```bash
  dart format lib test
  flutter analyze
  flutter test
  ```

## Organisation du travail

- **Une issue par tâche**, rattachée à une fonctionnalité du cahier des charges (F1, F2…) et à une milestone (un lot).
- Le backlog initial est dans [`docs/backlog.md`](docs/backlog.md), en attendant d'être converti en issues GitHub.
- Kanban dans GitHub Projects : `À faire` → `En cours` → `En revue` → `Fait`.

## Branches

- `main` est protégée et toujours stable. On ne pousse jamais directement dessus.
- Une branche par issue, préfixée par son type : `feat/12-swipe-card`, `fix/18-crash-permission`, `chore/ci-cache`, `docs/adr-drift`.
- Fusion par PR en **squash merge** : un commit propre par PR sur `main`.

## Commits — Conventional Commits

```
<type>(<portée facultative>): <résumé à l'impératif, en minuscules>
```

| Type | Usage |
|---|---|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `refactor` | Changement de code sans effet visible |
| `test` | Tests uniquement |
| `docs` | Documentation |
| `chore` | Outillage, dépendances, config |
| `ci` | Pipeline CI |

Exemples : `feat(swipe): ajoute l'annulation de la dernière décision`, `fix(cart): conserve le panier après un kill`.

## Code

- Architecture : `features/<feature>/{presentation,application}`, `data/{models,sources,repositories}` (voir le cahier des charges, §8.3).
- État : Riverpod, avec les classes `Notifier` / `AsyncNotifier` uniquement ([ADR 0004](docs/adr/0004-riverpod.md)).
- **Aucun texte en dur** dans l'UI : tout passe par `lib/l10n/app_fr.arb` (référence) et `app_en.arb`.
- **Aucune couleur en dur** : `Theme.of(context).colorScheme` ou `TidyColors.of(context)`.
- Noms de fichiers en `snake_case.dart`.
- Logique métier testée unitairement. Les écrans importants ont un test de widget.
- Une décision technique structurante = une nouvelle ADR dans `docs/adr/`.

## Versions

- SemVer : `0.x` jusqu'à la première publication sur les stores.
- Chaque PR notable ajoute une ligne dans `CHANGELOG.md`, section « Non publié ».
