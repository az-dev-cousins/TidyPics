# 📸 TidyPics — Cahier des charges

> Version 1.2 — 20/10/2026
> Statut : **périmètre V1 validé**
> Source de vérité : ce document, avec les décisions de [`docs/adr/`](adr/README.md) et la direction artistique de [`docs/design/`](design/direction-artistique.md).

---

## 1. Contexte et objectif

Les galeries de smartphone accumulent des milliers de photos inutiles : rafales, doublons, screenshots, photos ratées. Les trier est long et pénible, donc personne ne le fait.

**TidyPics** transforme ce tri en un moment rapide et ludique grâce à un swipe façon Tinder. L'app montre en permanence l'espace gagné pour motiver l'utilisateur.

**Principes directeurs**
- **100 % local** : aucun compte, aucun serveur. L'app ne fait elle-même aucune requête réseau.
- **Zéro perte accidentelle** : on passe par la corbeille système d'Android ou d'iOS (environ 30 jours avant l'effacement définitif).
- **Rien ne se perd** : chaque décision est enregistrée sur le téléphone dès qu'elle est prise. Un crash ou une fermeture de l'app ne fait perdre aucun tri.
- **Fun et léger** : animations fluides, retour visuel immédiat, pas de surcharge d'informations.
- **Motivation** : toujours montrer les gains (photos triées, espace libéré).

---

## 2. Périmètre

### Dans le périmètre (V1)
- Photos uniquement (pas de vidéos)
- Smartphones et **tablettes** (iPhone, iPad, Android)
- Tri par swipe : aléatoire (par défaut) ou ordonné
- Tri ciblé par année et par mois
- Panier de suppression avec checkpoint, puis envoi groupé à la corbeille système
- Vue « En cours de suppression » et **vidage de la corbeille** (Android)
- Photos similaires (rafales) et doublons JPG + RAW
- Statistiques d'espace gagné depuis l'installation
- Direction artistique et logo

### Hors périmètre
- ❌ Comptes, authentification, Firebase, tout backend
- ❌ Desktop et web
- ❌ Envoi de photos vers un cloud par l'app elle-même (cela demanderait un compte Google)

### Plus tard
- V2 : vidéos, succès, notifications locales, envoi vers le cloud via le menu de partage
- V3 : tous les types de fichiers, IA (flou, screenshots, meilleure photo)

---

## 3. Plateformes et contraintes système

### 3.1 Versions minimum

| | Minimum | Remarque |
|---|---|---|
| Android | **11 (API 30)** ✅ validé | Corbeille système disponible. Suppression sans popup possible à partir d'Android 12 (voir 3.3) |
| iOS / iPadOS | 15 | PhotoKit avec accès limité ou complet |

### 3.2 Comment chaque système gère la suppression

| | Android 11 | Android 12+ | iOS / iPadOS |
|---|---|---|---|
| Envoi à la corbeille | `createTrashRequest` | idem | `deleteAssets`, l'élément va dans « Récemment supprimés » |
| Popup de confirmation | **1 par lot** | **aucune** si la permission « Gestion des médias » est accordée, sinon 1 par lot | **1 par lot, impossible à contourner** |
| Lire la corbeille | ✅ | ✅ | ❌ Apple ne donne pas accès à « Récemment supprimés » |
| Restaurer depuis l'app | ✅ | ✅ | ❌ uniquement depuis l'app Photos |
| **Vider la corbeille** depuis l'app | ✅ `createDeleteRequest` (1 popup) | ✅ sans popup avec « Gestion des médias » | ❌ l'utilisateur doit le faire dans Photos (Face ID demandé) |
| Supprimer directement, sans corbeille | ✅ possible (option avancée) | ✅ | ❌ |
| Favori système | ✅ `createFavoriteRequest` | ✅ | ✅ `isFavorite` |

Référence : [Android — Access media files from shared storage](https://developer.android.com/training/data-storage/shared/media) (batch requests et « media management special permission »).

### 3.3 Permissions

| Permission | Plateforme | Quand on la demande | Si l'utilisateur refuse |
|---|---|---|---|
| Lecture des photos (`READ_MEDIA_IMAGES`) | Android | Fin de l'onboarding | L'app ne peut rien faire : écran expliquant comment l'autoriser dans les réglages |
| Accès partiel « photos sélectionnées » | Android 14+ | Choix proposé par le système | On trie seulement ces photos, avec un bandeau « Autoriser toutes les photos » |
| Photothèque (complet ou limité) | iOS | Fin de l'onboarding | Idem Android |
| **Gestion des médias** (`MANAGE_MEDIA`) | Android 12+ | **Au premier checkpoint**, avec une explication (« Supprime sans confirmation à chaque fois ») | Une popup système s'affiche à chaque lot. Rien n'est bloqué |

L'app ne demande **aucune permission réseau, de localisation ou de notification** en V1.

### 3.4 Cloud : ce qui se passe vraiment

**iPhone / iPad avec Photos iCloud activé**
- TidyPics voit **toute la photothèque iCloud**, y compris les photos qui ne sont plus stockées en entier sur l'appareil.
- Supprimer une photo la supprime **d'iCloud et de tous les appareils** (elle va dans « Récemment supprimés » partout pendant 30 jours). Le message de confirmation d'iOS le précise.
- Si « Optimiser le stockage » est activé, l'appareil ne garde souvent qu'une version allégée : l'espace libéré l'est surtout sur iCloud. Les stats parlent donc d'**espace libéré (appareil + iCloud)**.
- Pour afficher en grand une photo qui n'est que dans iCloud, iOS la télécharge. C'est le système qui fait la requête réseau, pas TidyPics.
- Le favori se synchronise avec iCloud sur tous les appareils.

**Android avec Google Photos (ou un autre cloud)**
- TidyPics ne voit que les photos **présentes sur le téléphone**. Les photos qui ne sont que dans Google Photos sont invisibles.
- Supprimer une photo libère l'espace **du téléphone**. ⚠️ **À vérifier par un test** : à notre connaissance, la copie sauvegardée dans Google Photos reste dans le cloud.
- Google ne fournit **aucune API publique pour supprimer** des photos de Google Photos. Nettoyer le cloud Google n'est donc pas possible pour une app tierce.
- Envoyer une photo vers Google Photos depuis l'app demanderait une connexion Google, ce qui va contre « aucun compte ». L'alternative retenue pour la V2 passe par le **menu de partage du système** (voir F1).

---

## 4. Fonctionnalités V1

Chaque fonctionnalité a un identifiant (Fx) qui sert de référence dans les tickets.

### F1 — Écran de tri par swipe

| Geste | Action |
|---|---|
| ⬅️ Swipe gauche | Ajouter au **panier de suppression** |
| ➡️ Swipe droite | **Garder** |
| ⬆️ Swipe haut | **Garder + Favori** (favori système de la galerie) ✅ validé |
| Bouton « Passer » | Pas de décision, la photo reviendra plus tard |
| Bouton ↩️ | **Annuler** la dernière décision (au moins les 10 dernières) |
| Bouton **« Je m'arrête là »** | Termine la session et ouvre le checkpoint (F3) |

- Chaque geste a aussi un bouton équivalent, pour l'accessibilité.
- Une animation confirme chaque décision (poubelle, check, étoile).
- Sur la carte : date, taille, badges « RAW », « Rafale » ou « iCloud » s'il y a lieu.
- Un compteur de session est visible : photos triées et Mo dans le panier.
- Une photo gardée **n'est plus reproposée**. Un réglage permet de remettre à zéro les photos gardées.
- **Tablette** : la carte est centrée avec une largeur maximum. En paysage, un panneau latéral affiche le panier et les stats de la session.
- **Plus tard (V2)** : un appui long sur un favori proposera « Envoyer vers… » (menu de partage du système, vers Google Photos, Drive, etc.). L'utilisateur n'a pas besoin de se connecter dans l'app.

**Critères d'acceptation**
- Le swipe reste fluide (60 fps) sur un appareil milieu de gamme, avec une galerie de 20 000 photos.
- La photo suivante est préchargée : aucun écran blanc entre deux cartes.

### F2 — Modes de tri
1. **Aléatoire (par défaut)** : les photos non triées sont tirées au hasard dans toute la galerie.
2. **Ordonné** (réglage) : de la plus ancienne à la plus récente, ou l'inverse.
3. **Ciblé par année et mois** (toujours accessible depuis l'accueil) : années, puis mois, avec pour chacun le nombre de photos et la part déjà triée. Choisir un mois lance une session limitée à ce mois.

**Règle :** les groupes (rafales F5, paires JPG + RAW F6) sont **tirés comme un seul élément**, jamais séparés.

### F3 — Panier et checkpoint

#### Principe
1. Le swipe gauche met la photo dans le **panier**, enregistré sur le téléphone **immédiatement**.
2. Le **checkpoint** est un écran récap qui affiche la grille du panier, l'espace à libérer et permet de retirer une photo d'un tap. Son bouton « Supprimer N photos (X Mo) » envoie tout le panier à la corbeille système **en un seul lot**.
3. Une photo du panier n'est pas encore supprimée : elle est toujours dans la galerie.

#### Quand le checkpoint s'affiche

| Situation | Ce qui se passe |
|---|---|
| Le panier atteint **50 photos** (réglable) | Le checkpoint est proposé. « Continuer » le repousse au prochain seuil |
| Bouton **« Je m'arrête là »** | Checkpoint immédiat, quel que soit le nombre de photos |
| Retour à l'accueil depuis le tri | Checkpoint immédiat si le panier n'est pas vide |
| L'utilisateur **sort de l'app** (bouton home, autre app, appel) | **Rien n'est supprimé.** La session est mise en pause. Au retour, on reprend exactement où on en était |
| L'app est **fermée** (swipe dans le multitâche) ou tuée par le système | Rien n'est perdu (panier enregistré). **À la prochaine ouverture**, un checkpoint s'affiche : « 15 photos en attente — Supprimer / Revoir / Plus tard » |
| « Plus tard » | Le panier reste. Un badge sur l'accueil le rappelle. Le checkpoint revient à l'ouverture suivante |
| L'utilisateur refuse la popup système | Les photos restent dans le panier. Rien n'est supprimé |
| Une photo du panier a été supprimée ailleurs (ex. depuis l'app Photos) | Elle est retirée du panier sans bruit |

**Option Android 12+ avec « Gestion des médias »** : un réglage « Envoyer le panier à la corbeille quand je quitte l'app » (désactivé par défaut). Le checkpoint devient facultatif, et il n'y a pas de risque puisque tout reste récupérable 30 jours dans la corbeille. Sur iOS, c'est impossible : la confirmation système exige que l'app soit ouverte.

**Ce qu'on ne fait pas** : supprimer quand l'app est en arrière-plan sans accord. iOS l'interdit, et Android ne le permet qu'avec l'option ci-dessus.

### F4 — « En cours de suppression » et vidage

- Liste des photos envoyées à la corbeille : miniature, date d'envoi, **jours restants** avant effacement définitif.
- **Android** :
  - Lecture de la vraie corbeille système.
  - Bouton **Restaurer**, pour une photo ou une sélection.
  - Bouton **« Vider maintenant »**, pour libérer l'espace tout de suite. Il ne touche **que les photos envoyées par TidyPics**, et une popup s'affiche, sauf avec « Gestion des médias ».
  - Option avancée : **suppression définitive directe** au checkpoint, sans passer par la corbeille. Désactivée par défaut, avec un avertissement clair.
- **iOS / iPadOS** :
  - Affichage du **journal tenu par l'app** (miniature, taille, date).
  - Aide guidée pour libérer l'espace tout de suite : « Photos > Albums > Récemment supprimés > Sélectionner > Tout supprimer », avec un bouton qui ouvre l'app Photos.
- Les entrées de plus de 30 jours sont retirées automatiquement du journal.

### F5 — Photos similaires (rafales)
- Une **rafale** = des photos prises à **moins de N secondes** d'intervalle (3 s par défaut, réglable de 1 à 10 s). Les rafales iOS natives (`burstIdentifier`) sont aussi reconnues.
- Les groupes sont calculés une fois, lors du scan de la galerie (sur la liste triée par date), puis mis à jour au fil des nouvelles photos. Le mode aléatoire tire ensuite ces groupes comme un seul élément.
- **Carte « Rafale (n) »** : elle ouvre une grille ou un carrousel où l'on coche **une ou plusieurs photos à garder**, puis « Garder la sélection, supprimer les autres ».
- Raccourci : swipe gauche sur le groupe = tout au panier, swipe droit = tout garder.
- Option : regroupement activé ou désactivé.

### F6 — Doublons JPG + RAW
- Une **paire** = même nom de fichier (hors extension) et même date de prise de vue, en JPG/HEIC d'un côté et en RAW de l'autre (`.dng`, `.cr2`, `.nef`, `.arw`…).
- **Mode dédié** depuis l'accueil : liste des paires et espace récupérable avec « Garder JPG / Garder RAW / Garder les deux », en masse ou paire par paire.
- En session de swipe : une carte unique avec le badge « JPG + RAW ».
- ⚠️ **iOS** : un import JPG + RAW forme souvent **un seul élément avec deux fichiers**. Il faut vérifier par un test si l'on peut n'en supprimer qu'un. Sinon, la fonction ne sert que sur Android en V1.

### F7 — Statistiques
- **Depuis l'installation** : espace libéré, photos supprimées, photos triées, sessions.
- **Par période** : semaine, mois, et courbe dans le temps.
- L'espace n'est compté qu'après l'envoi réel à la corbeille. Une photo restaurée est décomptée.
- Accueil : un gros chiffre « X Go libérés » et la progression du tri (% de la galerie triée).

### F8 — Paramètres
- Mode de tri : aléatoire, ou ordonné (ancien vers récent, ou l'inverse)
- Taille du lot avant checkpoint (50 par défaut)
- Écart en secondes pour les rafales, et regroupement on/off
- Android : accès à « Gestion des médias », envoi automatique en quittant l'app, suppression définitive directe
- Remettre à zéro les photos gardées
- Thème : clair / sombre / système

### F9 — Onboarding et accueil
- **Onboarding** en 3 écrans : le principe du swipe, « tes photos restent sur ton téléphone », puis la demande de permission avec une explication.
- **Accueil** : bouton « Trier », tri par année/mois, doublons JPG + RAW, « En cours de suppression », stats, paramètres. Badge sur le panier s'il y a des photos en attente.

---

## 5. Direction artistique et logo

✅ **Direction B « Clean & zen » validée.** Le détail (couleurs, typographie, formes, ton, 3 pistes de logo) est dans [`design/direction-artistique.md`](design/direction-artistique.md).

- Couleurs de sens fixes : **supprimer = tomate**, **garder = sapin (vert)**, **favori = étoile jaune soleil**. Elles sont toujours accompagnées d'une icône.
- Typographie : Manrope, incluse dans l'app.
- Thème clair et thème sombre dès la V1.
- Logo : le « t » paysage ✅.

---

## 6. Suppression en masse : fonctionnement détaillé

1. Au checkpoint, l'app prépare la liste des photos du panier.
2. **Android** : un seul `createTrashRequest` avec tous les éléments.
   - Android 11, ou 12+ sans « Gestion des médias » : **une seule popup** (« Autoriser TidyPics à placer 50 éléments dans la corbeille ? »).
   - Android 12+ avec « Gestion des médias » : aucune popup.
   - Si le lot est très gros, il sera découpé en interne (taille à mesurer lors du prototype à cause d'une limite technique d'Android). Avec « Gestion des médias », ce découpage est invisible. Sans, il peut y avoir plus d'une popup.
3. **iOS** : un seul `deleteAssets`, donc **une seule popup** (« Autoriser TidyPics à supprimer 50 photos ? », avec la mention « de tous vos appareils » si iCloud est activé).
4. Une fois l'opération acceptée, les photos sont inscrites dans le journal (F4), les stats sont mises à jour (F7) et le panier est vidé.
5. Si l'opération est refusée ou échoue, rien ne change et le panier est conservé.

---

## 7. Exigences non fonctionnelles

| Domaine | Exigence |
|---|---|
| Vie privée | Aucune requête réseau faite par l'app, aucune donnée collectée, pas d'analytics en V1 |
| Performance | Premier affichage < 2 s. Scan d'une galerie de 20 000 photos en tâche de fond, sans bloquer l'UI. Miniatures uniquement dans les listes |
| Fiabilité | Le panier, les décisions, le journal et les stats survivent à un crash ou à un kill |
| Accessibilité | Un bouton pour chaque geste, compatibilité avec le grand affichage système, couleurs doublées d'icônes |
| Langues | Français en V1, structure prête pour l'anglais (fichiers ARB) |
| Qualité | `flutter analyze` sans warning, tests unitaires sur la logique métier, CI à chaque PR |

---

## 8. Architecture technique

### 8.1 Stack
- Flutter (Dart 3.5+), Material 3
- `photo_manager` pour la galerie, les miniatures, les suppressions et les favoris
- **Code natif Android en Kotlin** pour ce que `photo_manager` ne fait pas : lire la corbeille, restaurer, vider, « Gestion des médias »
- Stockage local : **Drift** (SQLite) pour les décisions, le panier, le journal, les groupes et les stats, `shared_preferences` pour les réglages
- Gestion de l'état : **Riverpod** ✅ ([ADR 0004](adr/0004-riverpod.md))
- Navigation : **go_router** ([ADR 0005](adr/0005-go-router.md))

### 8.2 Riverpod ou Bloc

| | Riverpod | Bloc |
|---|---|---|
| Principe | Des « providers » qui exposent des données et se recalculent quand une dépendance change | Des événements entrent (`SwipeLeft`), des états sortent (`SessionState`), le tout de façon très encadrée |
| Quantité de code | ✅ Peu de code, rapide à écrire seul | ❌ Verbeux : une classe par événement et par état |
| Données asynchrones (scan de la galerie, base de données) | ✅ Très naturel (`AsyncValue` : chargement / données / erreur) | 🟡 Possible, mais plus de code |
| Logique complexe (session de swipe, annulation, checkpoint) | 🟡 Possible, à structurer soi-même | ✅ Son point fort : chaque événement est tracé, facile à déboguer |
| Injection des dépendances (repositories) | ✅ Intégrée | ❌ Il faut un outil en plus (`RepositoryProvider` ou `get_it`) |
| Tests | ✅ Simple : on remplace un provider | ✅ Simple, avec `bloc_test` |
| Apprentissage | 🟡 Plusieurs façons d'écrire (avec ou sans génération de code), ce qui peut dérouter | ✅ Une seule façon de faire, très cadrée |
| Marché du travail | Très répandu | Très répandu, surtout en entreprise et dans les grosses équipes |

**Décision : Riverpod** ✅. Le projet est porté par un développeur seul, et la majorité de l'app consiste à afficher des données locales asynchrones, ce qui est le point fort de Riverpod. Une seule partie complexe (la session de swipe) reste gérable avec un notifier bien testé. Bloc se défend si l'objectif principal est d'apprendre le standard des grosses équipes.

### 8.3 Structure du code
```plaintext
lib/
├── main.dart             # point d'entrée : ProviderScope + TidyPicsApp
├── app/
│   ├── app.dart          # MaterialApp.router, thèmes, langues
│   └── router.dart       # routes go_router
├── core/
│   ├── theme/            # app_colors, app_theme (clair / sombre)
│   └── utils/
├── l10n/                 # app_fr.arb, app_en.arb (textes traduits)
├── data/
│   ├── models/           # Photo, PhotoGroup, TrashEntry, Stats
│   ├── sources/          # gallery_source, native_trash_source (Android), local_db
│   └── repositories/     # gallery, deletion, stats
├── features/             # un dossier par écran : <feature>/presentation, <feature>/application
│   ├── onboarding/  home/  swipe/  browse/  cart/
│   ├── trash/  raw_pairs/  stats/  settings/
└── shared/widgets/       # widgets réutilisables
```

### 8.4 Données locales

| Table | Contenu |
|---|---|
| `photo_decision` | asset_id, décision (kept / favorite / in_cart / trashed), date |
| `photo_group` | group_id, type (burst / raw_pair), asset_ids |
| `cart` | asset_id, taille, date d'ajout |
| `trash_log` | asset_id, miniature (~10 Ko), taille, date d'envoi |
| `stats_event` | type, octets, nb photos, date |

---

## 9. Organisation du projet

- **Docs** : `docs/` remplace `dev_docs/`.
  - `docs/cahier-des-charges.md`
  - `docs/design/` (DA, logo, maquettes)
  - `docs/adr/` (une fiche courte par décision technique, ex. « 0001 — Riverpod »)
  - Les anciennes notes sont archivées ou supprimées.
- **README** : court. Pitch, captures, comment lancer le projet, liens vers les docs.
- **Suivi** : GitHub Issues (une par fonctionnalité Fx ou par tâche), Milestones (un par lot, voir §11), GitHub Project en kanban, labels (`feature`, `bug`, `tech`, `design`, `android`, `ios`).
- **Git** : `main` protégée, branches `feat/…`, `fix/…`, `chore/…`, fusion par PR (même seul, pour garder l'historique et faire passer la CI). Pas de branche `dev` : inutile pour un développeur seul.
- **Commits** : Conventional Commits (`feat:`, `fix:`, `chore:`…), versions en SemVer, `CHANGELOG.md`.
- **CI** (GitHub Actions) : `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, build Android à chaque PR.
- **Qualité** : règles de lint plus strictes, `CLAUDE.md` pour documenter les conventions.

---

## 10. Points ouverts

| # | Sujet | Statut |
|---|---|---|
| 1 | Android 11 minimum | ✅ validé ([ADR 0003](adr/0003-android-11-minimum.md)) |
| 2 | Vidéos | ✅ V2/V3 |
| 3 | Swipe haut = Garder + Favori | ✅ validé |
| 4 | Checkpoint (§F3) et envoi auto en quittant l'app (Android 12+) | ✅ validé |
| 5 | Riverpod | ✅ validé ([ADR 0004](adr/0004-riverpod.md)) |
| 6 | Direction artistique B « Clean & zen » | ✅ validé |
| 7 | « Gestion des médias » demandée au premier checkpoint | ✅ validé |
| 8 | iOS en accès limité accepté, avec un bandeau | ✅ validé |
| 9 | Logo : « t » paysage | ✅ validé |
| 10 | Test : Google Photos garde-t-il la copie cloud ? | 🔬 prototype (lot 0bis) |
| 11 | Test : JPG + RAW sur iOS | 🔬 prototype (lot 0bis) |
| 12 | Package Android renommé en `com.azancoth.tidypics` | ✅ fait au lot 0 |

---

## 11. Découpage en lots

| Lot | Contenu | Résultat attendu |
|---|---|---|
| 0 — Socle | Organisation (§9), DA et logo, nettoyage du template, dépendances, thème, CI | L'app démarre avec la bonne identité visuelle |
| 0bis — Prototypes | Tests techniques : corbeille Android et « Gestion des médias », Google Photos, JPG + RAW sur iOS | Points 9 et 10 tranchés |
| 1 — Galerie | Permissions, onboarding, scan, base locale | La galerie est indexée |
| 2 — Swipe | F1 et F2 (aléatoire, ordonné, annuler, favori) | On peut trier |
| 3 — Suppression | F3, F4 et §6 | On libère réellement de l'espace |
| 4 — Stats | F7 et accueil final | Les gains sont visibles |
| 5 — Ciblé | Tri par année et mois | Tri ciblé possible |
| 6 — Groupes | F5 et F6 | **MVP complet** |
| 7+ | Vidéos, succès, notifications, partage vers le cloud, IA | V2 / V3 |
