# 📸 TidyPics - Use Cases

## 🎯 Use Case 1 : Authentification et création de compte

**Acteurs principaux :**
- Utilisateur
- Système Firebase Auth

**Scénario principal :**
1. L’utilisateur ouvre l’application pour la première fois.
2. L’application propose plusieurs méthodes d’inscription :
    - Email + mot de passe
    - Numéro de téléphone
    - Compte Google
    - Compte Facebook
3. L’utilisateur choisit sa méthode et s’authentifie.
4. Son compte est créé et associé à un espace utilisateur personnel dans la DB.

**Extensions :**
- Si l’utilisateur a déjà un compte, il peut simplement se connecter.
- TODO : Gérer le reset du mot de passe.

---

## 🎯 Use Case 2 : Découverte et tri des photos

**Acteurs principaux :**
- Utilisateur

**Scénario principal :**
1. L’utilisateur accède à l’écran principal.
2. Il voit ses photos sous forme de cartes à swiper (façon Tinder) :
    - ➡️ Swipe droite = conserver
    - ⬅️ Swipe gauche = supprimer
3. Les photos s’affichent **des plus anciennes aux plus récentes**.
4. Une animation confirme la décision (ex: icône poubelle ou cœur).

**Extensions :**
- Possibilité de changer l’ordre d’affichage (TODO : tri inverse, tri par taille, etc.).
- Si photos similaires détectées : l’application les regroupe et propose de choisir la meilleure.

---

## 🎯 Use Case 3 : Gestion du cache temporaire des suppressions

**Acteurs principaux :**
- Utilisateur
- Système de gestion du cache

**Scénario principal :**
1. Lorsqu’une photo est « supprimée » via swipe, elle n’est pas effacée immédiatement.
2. Elle est placée dans un cache temporaire pendant **30 à 40 jours**.
3. Une page dédiée « Cache » permet à l’utilisateur de :
    - Voir les photos en attente de suppression
    - Consulter le nombre de jours restants avant suppression définitive
    - Restaurer une photo dans sa galerie

**Extensions :**
- TODO : permettre un vidage manuel immédiat.

---

## 🎯 Use Case 4 : Page récap / vue en grille

**Acteurs principaux :**
- Utilisateur

**Scénario principal :**
1. L’utilisateur accède à la page récapitulative.
2. Il voit ses photos conservées sous forme de **grille**, regroupées par mois.
3. Il visualise :
    - Nombre de photos gardées par mois
    - Espace de stockage économisé
4. Il peut relancer un tri sur un mois précis.

**Extensions :**
- TODO : statistiques globales (nombre total trié, % d’économies).

---

## 🎯 Use Case 5 : Paramètres et préférences utilisateur

**Acteurs principaux :**
- Utilisateur

**Scénario principal :**
1. L’utilisateur accède à la page paramètres.
2. Il peut :
    - Activer / désactiver la suppression automatique après 30-40 jours
    - Gérer les notifications (TODO)
    - Modifier l’ordre d’affichage des photos

---

## 🎯 Use Case 6 : Suppression automatique des photos expirées

**Acteurs principaux :**
- Système

**Scénario principal :**
1. Au lancement de l’application, le système vérifie les dates d’expiration des photos dans le cache.
2. Si la durée est dépassée, les photos sont supprimées définitivement.
3. TODO : prévoir une option avancée pour suppression en arrière-plan.

---

## 🎯 Use Case 7 : Regroupement des photos similaires (option avancée)

**Acteurs principaux :**
- Utilisateur

**Scénario principal :**
1. L’utilisateur active une option pour regrouper les photos similaires (prises à quelques secondes/minutes d’intervalle).
2. Lors du tri, l’utilisateur voit ces photos sous forme d’un mini carrousel pour sélectionner la meilleure.

**Extensions :**
- TODO : IA pour recommander la photo la plus nette ou la plus jolie.

---

# 📝 Notes d'identité de conception

- 🔥 **Ton de l’app :** jeune, léger, fun, à la Tinder, pour dédramatiser le ménage photo.
- 💾 **Sécurité des données :** Firebase Auth pour la connexion, Firestore pour stocker les stats et préférences.
- ⏳ **Philosophie du cache :** l’utilisateur a toujours un délai de grâce avant suppression, pour jamais rien perdre par accident.
- 📊 **Clarté :** toujours indiquer les gains (photos triées, espace économisé) pour motiver l’utilisateur.
- 💡 **Scalabilité prévue :** futur support d’IA pour identifier les flous, doublons, etc.
- 🎨 **UI :** animations fluides, feed-back visuel immédiat sur chaque swipe, et pas d’overload d’infos.

---

✅ Voilà ton concept version **use case + ADN**.  
Dis-moi si tu veux que je te fasse un petit tableau RACI (qui fait quoi), un diagramme d’états ou carrément un flow interactif. On peut affiner tout ça easy.