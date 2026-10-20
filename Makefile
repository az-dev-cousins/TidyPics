# Raccourcis du projet. Lancer « make » seul pour voir la liste.
.DEFAULT_GOAL := help
.PHONY: help photos-android photos-android-clean photos-ios videos-android videos-android-big videos-android-clean check

help: ## Affiche cette aide
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-22s %s\n", $$1, $$2}'

photos-android: ## Envoie les photos de test sur l'émulateur Android démarré
	tool/seed_test_photos.sh android

photos-android-clean: ## Retire les photos de test de l'émulateur Android
	tool/seed_test_photos.sh android --clean

photos-ios: ## Ajoute les photos de test au simulateur iOS démarré
	tool/seed_test_photos.sh ios

videos-android: ## Crée 3 petites vidéos de test sur l'émulateur Android
	tool/seed_test_videos.sh

videos-android-big: ## Idem, plus une grosse vidéo (~120 Mo) qui passe en tête du tri
	tool/seed_test_videos.sh --big

videos-android-clean: ## Retire les vidéos de test de l'émulateur Android
	tool/seed_test_videos.sh --clean

check: ## Format, analyse et tests (à lancer avant de pousser)
	dart format lib test
	flutter analyze
	flutter test
