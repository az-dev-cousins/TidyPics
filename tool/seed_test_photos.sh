#!/usr/bin/env bash
# Envoie les photos de test sur un émulateur Android ou un simulateur iOS.
#
# Usage :
#   tool/seed_test_photos.sh android          # génère si besoin, puis envoie
#   tool/seed_test_photos.sh android --clean  # supprime les photos de test
#   tool/seed_test_photos.sh ios              # simulateur iOS démarré
#
# Les photos viennent de tool/generate_test_photos.dart (build/test_photos).
set -euo pipefail

cd "$(dirname "$0")/.."

PLATFORM="${1:-}"
ACTION="${2:-}"
SRC="build/test_photos"
ANDROID_DIR="/sdcard/DCIM/TidyPicsTest"

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

generate_if_needed() {
  if [ ! -d "$SRC" ] || [ -z "$(ls -A "$SRC")" ]; then
    echo "Génération des photos de test…"
    dart run tool/generate_test_photos.dart "$SRC"
  fi
}

find_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
  elif [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
    echo "$ANDROID_HOME/platform-tools/adb"
  elif [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
    echo "$HOME/Library/Android/sdk/platform-tools/adb"
  else
    echo "adb introuvable : installe les platform-tools du SDK Android." >&2
    exit 1
  fi
}

# Demande à Android de réindexer le stockage pour que la galerie
# (et TidyPics) voient les ajouts et les suppressions.
android_rescan() {
  "$ADB" shell content call --uri content://media --method scan_volume \
    --arg external_primary >/dev/null
}

case "$PLATFORM" in
  android)
    ADB="$(find_adb)"
    if [ "$("$ADB" get-state 2>/dev/null)" != "device" ]; then
      echo "Aucun émulateur Android connecté. Lance-le d'abord (ex. flutter emulators --launch Pixel_7)." >&2
      exit 1
    fi
    if [ "$ACTION" = "--clean" ]; then
      "$ADB" shell rm -rf "$ANDROID_DIR"
      android_rescan
      echo "Photos de test supprimées de l'émulateur."
      exit 0
    fi
    generate_if_needed
    "$ADB" shell rm -rf "$ANDROID_DIR"
    "$ADB" shell mkdir -p "$ANDROID_DIR"
    "$ADB" push "$SRC/." "$ANDROID_DIR/" >/dev/null
    android_rescan
    echo "$(ls "$SRC" | wc -l | tr -d ' ') fichiers envoyés dans $ANDROID_DIR."
    ;;
  ios)
    if [ "$ACTION" = "--clean" ]; then
      echo "simctl ne sait pas supprimer des photos : utilise l'app Photos du simulateur," >&2
      echo "ou repars de zéro avec « xcrun simctl erase <simulateur> » (efface tout le simulateur)." >&2
      exit 1
    fi
    if ! xcrun simctl list devices booted | grep -q Booted; then
      echo "Aucun simulateur iOS démarré. Lance-le d'abord (ex. open -a Simulator)." >&2
      exit 1
    fi
    generate_if_needed
    # Photos ne sait pas importer les faux RAW (.DNG) : on les laisse de côté.
    find "$SRC" -type f ! -iname '*.dng' -print0 | xargs -0 xcrun simctl addmedia booted
    echo "Photos ajoutées au simulateur iOS (sans les faux RAW)."
    ;;
  *)
    usage
    ;;
esac
