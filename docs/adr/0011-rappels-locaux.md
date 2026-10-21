# 0011 — Rappels façon jeu, programmés sur le téléphone

- Statut : Acceptée
- Date : 2026-10-21

## Contexte
On veut des rappels quotidiens « à la Duolingo » pour revenir trier, avec un texte juste (série en cours, photos de la semaine), sans serveur ([ADR 0001](0001-app-100-pourcent-locale.md)) et sans devenir pénible.

## Décision
- **Notifications locales** (`flutter_local_notifications`), programmées par l'app au moment choisi à l'onboarding (matin, après-midi, soir). L'heure précise est celle où l'on ouvre le plus souvent l'app dans ce moment de la journée (compte des ouvertures par heure, gardé sur le téléphone), sinon 8 h, 13 h ou 19 h.
- En quittant l'app, une **série** est programmée à partir de cette visite : J+1, J+2, J+3, puis J+5, J+7, J+14 (hebdomadaire : J+7, J+14, J+28). Revenir trier reprogramme tout : les rappels restent quotidiens tant qu'on revient, puis s'espacent.
- **Android** : une tâche de fond (`workmanager`, toutes les 12 h) relit la base et la galerie et remet à jour les textes, par exemple pour « 30 photos ou plus cette semaine » une fois la galerie triée à 90 %. iOS ne garantit pas ce réveil : les textes datent de la dernière visite.
- Heure non exacte (`inexactAllowWhileIdle`) : pas de permission d'alarme exacte. L'instant est donné en UTC (paquet `timezone`), sans avoir besoin du fuseau.
- La planification est une fonction pure et testée (`reminder_plan.dart`).

## Conséquences
- Rien ne quitte le téléphone ; la permission de notifier n'est demandée que si l'on choisit un moment.
- La tâche de fond ajoute les permissions `FOREGROUND_SERVICE` (déclarées par `workmanager`) ; elle ne dure que quelques secondes.
- « Photos de la semaine » compte les photos **ajoutées** au téléphone ces 7 jours (photos reçues comprises), ce qui suffit pour un retour de vacances.
