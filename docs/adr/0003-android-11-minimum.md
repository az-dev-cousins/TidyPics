# 0003 — Android 11 minimum (API 30)

- Statut : Acceptée
- Date : 2026-10-20

## Contexte
La corbeille système (`createTrashRequest`) et les favoris système (`createFavoriteRequest`) n'existent qu'à partir d'Android 11. En dessous, une suppression est définitive.

## Décision
`minSdk = 30`. iOS minimum : 15.

## Conséquences
- ✅ Une seule logique de suppression sur Android, toujours récupérable.
- ➖ Les appareils sous Android 10 ou moins sont exclus (part de marché faible en 2026).
- Note : la suppression sans popup (`MANAGE_MEDIA`) demande Android 12. Sur Android 11, il y a une popup par lot.
