# Direction artistique — Clean & zen

> Statut : direction et logo validés.
> Planche visuelle : https://claude.ai/artifact/AejtVxSSrTAgEdonFSWNow

## Intention

TidyPics doit procurer un **soulagement** : on range, on respire, on libère de la place.
Mots-clés : calme, clarté, léger, bienveillant.

## Couleurs

Ces valeurs sont la source de vérité pour `lib/core/theme/app_colors.dart`.

### Marque

| Nom | Clair | Sombre | Usage |
|---|---|---|---|
| Papier / Nuit | `#F6F5F0` | `#101413` | Fond de l'app |
| Surface | `#FFFFFF` | `#1A2221` | Cartes, feuilles |
| Encre | `#22272B` | `#E8ECEA` | Texte principal |
| Encre douce | `#5C666D` | `#9AA5A1` | Texte secondaire (contraste ≥ 4.5:1) |
| Trait | `#DAD7CC` | `#2E3B37` | Bordures, séparateurs |
| Menthe | `#BFE8D6` | `#1F3B33` | Surfaces d'accent, puces |
| Sapin / Menthe vive | `#1E7A64` | `#6FD3B1` | Couleur principale, liens, boutons |
| En-tête | `#1E7A64` (texte blanc) | `#173A30` (texte menthe `#BFE8D6`) | Grande carte « espace libéré » (menu, stats). En sombre, jamais d'aplat menthe vive : il éblouit |
| Fond de photo | `#EFEEE8` | `#0B0F0E` | Autour d'une photo dans une carte (bandes haut et bas) |
| Fond RAW | `#1E7A64` | `#145243` | Tri des RAW : fond vert dans les deux thèmes, pour le distinguer du tri habituel |
| Neutre graphique | `#9E998C` | `#7F8C87` | Catégorie « Autre » des graphiques, toujours légendée |

### Actions (fixes, quelle que soit l'évolution de la marque)

| Action | Clair | Sombre | Forme |
|---|---|---|---|
| Supprimer | Tomate `#E04A32` | `#FF7B63` | Bouton cerclé, icône ✕ |
| Garder | Sapin `#1E7A64` | `#6FD3B1` | Bouton plein, icône ✓ |
| Favori | Soleil `#FFC21A` (contour `#D99A00`) | `#FFC21A` | **Étoile seule**, dans un bouton neutre |

Règles :
- Une action est **toujours accompagnée de son icône** (✕, ✓, ★). La couleur seule ne porte jamais l'information.
- Le jaune ne sert **qu'à l'étoile du favori** : jamais en aplat, jamais dans le logo, jamais en texte.
- Pas de texte tomate sur fond clair en dessous de 18 px.

## Typographie

**Manrope** uniquement, embarquée dans l'app (`assets/fonts/manrope`, licence OFL). L'app ne la télécharge pas au lancement, car TidyPics ne fait aucun appel réseau.

| Style | Graisse | Taille | Exemple |
|---|---|---|---|
| Display | 800 | 40–48 | « 12,4 Go libérés » |
| Titre | 700 | 22–28 | « Avant de supprimer » |
| Texte | 400 | 15–16 | Corps de texte |
| Label | 600 | 12–13, majuscules | « 14 JUIL. 2019 · 3,2 MO » |

## Formes et mouvement

- Coins arrondis : 14 px pour les miniatures, 16–18 px pour les cartes d'info, 28 px pour la carte de swipe, boutons en pilule.
- Ombres douces et basses (`0 12 32 rgba(20,30,28,.12)`), pas de dégradés.
- Animations « ressort » souples : la carte suit le doigt puis revient ou s'envole, sans rebond excessif.
- Zones tactiles d'au moins 44 px.
- Une action principale par écran.

## Ton

- Tutoiement, phrases courtes, rassurantes.
- Exemples : « Tes photos restent sur ton téléphone. » · « Récupérables pendant 30 jours. » · « Je m'arrête là ».

## Logo

✅ **Logo retenu : le « t » paysage.** Un « t » blanc se dresse dans un paysage (colline menthe et soleil) sur fond sapin : le côté « rangé » (tidy) et le côté « photo » (pics) dans un seul symbole.

| Fichier (`docs/design/logo/`) | Usage |
|---|---|
| `tidypics-logo.svg` | Logo de référence, coins arrondis |
| `tidypics-icon-square.svg` | Icône d'app iOS et Android classique (le système applique ses propres coins) |
| `tidypics-icon-adaptive-background.svg` / `-foreground.svg` | Icône adaptative Android : fond (paysage) et premier plan (« t ») séparés |
| `explorations/` | Pistes non retenues, pour mémoire |

Wordmark : `tidypics` en Manrope 800, minuscules, avec « tidy » en Encre et « pics » en Sapin.

### Régénérer les icônes et l'écran de démarrage

1. Rendre chaque SVG en PNG 1024×1024 **avec transparence** dans `assets/icon/` (`icon.png`, `adaptive-background.png`, `adaptive-foreground.png`) et `splash-logo.png` (logo arrondi, 768×768). Chrome headless convient (`--screenshot --default-background-color=00000000`). L'aperçu macOS (`qlmanage`) ne convient pas : il ajoute un fond blanc.
2. `dart run flutter_launcher_icons`, puis `dart run flutter_native_splash:create`.
3. Vérifier que `ios/Runner.xcodeproj/project.pbxproj` n'a pas été modifié par erreur (le générateur d'icônes y touche parfois un réglage sans rapport).

On ne retouche jamais les PNG à la main : la source, ce sont les SVG.
