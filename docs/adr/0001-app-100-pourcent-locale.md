# 0001 — App 100 % locale, sans compte

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
Les premières notes prévoyaient Firebase Auth, Firestore et FCM. Or trier les photos de son téléphone ne demande aucune donnée côté serveur, et exiger un compte freine l'adoption tout en inquiétant sur la vie privée.

## Décision
- Aucun compte, aucun backend, aucun SDK d'analytics.
- L'app ne fait **aucune requête réseau**. Les polices sont incluses dans l'app.
- Toutes les données (décisions, panier, journal, stats) restent sur le téléphone.

## Conséquences
- ✅ Argument fort : « tes photos ne quittent jamais ton téléphone ».
- ✅ Pas de coût serveur, pas de RGPD côté serveur.
- ➖ Pas de synchronisation des stats entre appareils.
- ➖ Envoyer des photos vers Google Photos demanderait une connexion Google : on passera par le menu de partage du système (V2).
