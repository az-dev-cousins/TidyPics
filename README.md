# TidyPics 📸

## 🚀 À propos du projet

**TidyPics** est une application mobile multiplateforme (Flutter) qui réinvente le tri des photos et fichiers de ton smartphone.  
Inspirée de l'expérience swipe de Tinder, elle permet de parcourir facilement tes galeries, de supprimer les doublons, les photos inutiles ou floues, et de garder uniquement ce qui compte vraiment.

L'objectif est de transformer le fastidieux nettoyage de stockage en un moment ludique, rapide et satisfaisant.

---

## ✨ Ambitions & vision

- Créer la **référence du tri intelligent des médias sur smartphone**, avec une UX fluide et addictive.
- Devenir une app à impact : aider les utilisateurs à réduire leur empreinte digitale (moins de stockage inutile, moins de cloud superflu).
- Évoluer ensuite vers un outil global de gestion des fichiers.
- Intégrer des fonctionnalités d’**IA** pour détecter les doublons, les photos floues ou les screenshots obsolètes.

---

## 🔥 Fonctionnalités clés prévues

✅ Swipe intuitif :
- Swipe à gauche pour supprimer, à droite pour conserver.

✅ Statistiques dynamiques :
- Espace disque économisé, nombre de photos nettoyées, temps gagné.

✅ Gestion des utilisateurs via **Firebase** :
- Authentification (Google, email)
- Sauvegarde des préférences et historique

✅ Notifications push :
- Rappeler à l'utilisateur de nettoyer régulièrement son appareil

✅ Dark Mode & Responsive :
- UX adaptée aux mobiles, tablettes et même aux écrans desktop.

✅ Personnalisation :
- Paramètres pour ajuster les seuils de détection automatique (flou, doublons).

✅ Prévisions IA futures :
- Suggestions automatiques de suppression
- Reconnaissance de types d'images (mèmes, factures, notes temporaires)

---

## 🏗 Structure technique initiale

```plaintext
lib/
├── main.dart
├── app.dart
├── core/
│    ├── config/
│    │    ├── firebase_options.dart
│    │    └── env.dart
│    ├── themes/
│    │    ├── app_theme.dart
│    │    └── colors.dart
│    ├── utils/
│    │    └── formatters.dart
│    └── constants.dart
├── data/
│    ├── models/
│    │    ├── photo_model.dart
│    │    └── user_prefs_model.dart
│    ├── datasources/
│    │    ├── firebase_auth_service.dart
│    │    ├── firestore_user_prefs_service.dart
│    │    └── firebase_notification_service.dart
│    └── repositories/
│         ├── photo_repository.dart
│         └── user_repository.dart
├── features/
│    ├── auth/
│    ├── home/
│    ├── swipe/
│    ├── settings/
│    └── notifications/
└── shared/
     ├── widgets/
     └── services/
```

---

## 🚀 Stratégie de commercialisation

### 🎯 Positionnement

-

---

### 💡 Acquisition & diffusion

-

---

### 💵 Business model & monétisation
- **Freemium** 
- **Premium** 

---

## 🔄 Work flow du projet

### 🚀 Méthodologie
- Workflow git structuré :
  - `main` pour les versions stables,
  - `dev` pour l’intégration continue,
  - `feature/xxx` pour les évolutions.
- Gestion des tâches via GitHub Projects (kanban agile).
- CI/CD envisagé via GitHub Actions pour builder automatiquement, analyser le code (`flutter analyze`) et lancer les tests.

### 🤝 Collaboration
Le projet est conçu pour être facilement maintenable et évolutif, avec une architecture modulaire et des conventions strictes, pour faciliter l'arrivée future d'autres développeurs.

---

## 📝 Liste détaillée des tâches

👉 Toutes les user stories et tâches techniques sont listées dans [task_list.md](dev_docs/TASK_LIST.md) et [user_story.md](dev_docs/USER_STORY.md)

---

## 🚀 Conclusion

TidyPics n’est pas qu’un simple cleaner : c’est un **outil intelligent et fun pour redonner vie à ton smartphone**, te faire gagner de l’espace et t’apporter un vrai sentiment de satisfaction.

**Ready to swipe, clean & chill ?**
