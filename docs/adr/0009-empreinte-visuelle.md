# 0009 — Empreinte visuelle calculée sur le téléphone

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
Deux besoins :
- **Doublons** (F11) : la même photo enregistrée plusieurs fois, par exemple l'original et la copie recompressée par WhatsApp. Ni le nom, ni la date, ni la taille du fichier ne coïncident.
- **Rafales** (F5) : le seul écart de temps groupait des photos différentes, comme plusieurs photos WhatsApp reçues à la même seconde.

L'app ne fait aucune requête réseau ([ADR 0001](0001-app-100-pourcent-locale.md)) : pas de service de reconnaissance d'images.

## Décision
Chaque photo reçoit une **empreinte visuelle**, calculée sur le téléphone à partir d'une miniature de 64 pixels, en tâche de fond après chaque scan, dans un isolate pour ne pas ralentir l'interface :
- **formes** : dHash 64 bits (image réduite à 9 × 8 en niveaux de gris, un bit par comparaison de deux pixels voisins). Sert à trouver vite les candidates ;
- **détails** : le même calcul en 17 × 16 (256 bits), pour confirmer ;
- **couleurs** : la couleur moyenne des quatre quarts de l'image.

Deux photos sont la même si elles ont les mêmes proportions, au plus 4 bits d'écart sur les formes, au plus 20 sur les détails et des couleurs proches. Pour ne pas comparer chaque photo à toutes les autres, les formes sont coupées en 5 morceaux : deux empreintes à 4 bits ou moins d'écart partagent forcément un morceau, on ne compare que celles-là. Chaque photo d'un groupe doit ressembler à la meilleure (pas de proche en proche).

Les empreintes sont stockées dans la table `photos` (base v3), calculées une seule fois.

## Conséquences
- Tout reste sur le téléphone. Quelques minutes de calcul la première fois pour une grosse galerie, puis seulement les nouvelles photos.
- Le paquet `image` (Dart pur) passe des dépendances de développement aux dépendances de l'app.
- Un essai sur les photos de test a montré que les formes seules ne suffisent pas : des photos de même composition (ciel, soleil, colline) se confondaient. D'où les couleurs et les détails.
- Les vidéos, les RAW (traités par F6) et les images presque unies ne sont pas comparées.
- Limite : deux photos très semblables prises à des moments différents (même paysage, même cadrage) peuvent être proposées comme doublons. Rien ne part sans validation, et un tap les garde toutes.
