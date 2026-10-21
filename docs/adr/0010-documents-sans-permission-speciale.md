# 0010 — Documents par le sélecteur du système, corbeille de TidyPics

- Statut : Acceptée
- Date : 2026-10-21

## Contexte
Trier les documents (PDF, Word, téléchargements) demande de les lire. Depuis Android 11, une app ne voit pas les documents des autres apps sans la permission « Accès à tous les fichiers » (`MANAGE_EXTERNAL_STORAGE`), que le Play Store refuse sauf pour les gestionnaires de fichiers. La rubrique « Documents » du gestionnaire de fichiers d'Android est une app du système, avec des droits qu'une app normale n'a pas.

## Décision
- Tout passe par le **sélecteur du système** (Storage Access Framework), sans permission :
  - « Mes documents » : l'utilisateur donne une fois l'accès à un dossier (Documents proposé d'abord). L'accès est gardé, le dossier relu à chaque fois.
  - « Trier des fichiers » : le sélecteur, plusieurs fichiers à la fois, n'importe où (Téléchargements…).
- La **corbeille du système refuse les documents** : `createTrashRequest` répond « All requested items must be Media items » (vérifié sur l'émulateur, Android 16). Les documents écartés vont donc dans la **corbeille de TidyPics** : copiés dans le stockage de l'app, effacés de leur dossier, récupérables 30 jours (remis dans leur dossier d'origine, ou dans Téléchargements), puis effacés.
- Aperçus sur le téléphone : `PdfRenderer` (Android) pour la première page des PDF ; le texte des .docx / .pptx / .xlsx / .odt est lu dans le fichier (une archive zip de XML) avec le paquet `archive`.

## Conséquences
- La fonction marche aussi dans une future version des stores : plus besoin d'en faire une exclusivité de l'APK.
- Un peu moins direct que « tout lister » : il faut donner l'accès au dossier une fois, ou choisir les fichiers.
- Android interdit de donner la racine de « Téléchargements » comme dossier : pour les téléchargements, on passe par « Trier des fichiers ».
- Pendant 30 jours, un document écarté prend encore de la place (dans l'app). « Vider les documents » la libère tout de suite.
- Android seulement : sur iOS, chaque app ne voit que ses propres fichiers.
