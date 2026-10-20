# Raccourcis du projet. Lancer « make » seul pour voir la liste.
.DEFAULT_GOAL := help
.PHONY: help photos-android photos-android-clean photos-ios check

help: ## Affiche cette aide
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-22s %s\n", $$1, $$2}'

photos-android: ## Envoie les photos de test sur l'émulateur Android démarré
	tool/seed_test_photos.sh android

photos-android-clean: ## Retire les photos de test de l'émulateur Android
	tool/seed_test_photos.sh android --clean

photos-ios: ## Ajoute les photos de test au simulateur iOS démarré
	tool/seed_test_photos.sh ios

check: ## Format, analyse et tests (à lancer avant de pousser)
	dart format lib test
	flutter analyze
	flutter test
