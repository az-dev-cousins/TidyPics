#!/usr/bin/env bash
# Crée des vidéos de test directement sur l'émulateur Android (enregistrement
# de l'écran pendant qu'il défile : pas besoin de ffmpeg).
#
# Usage :
#   tool/seed_test_videos.sh             # 3 petites vidéos (~3 Mo, 4 s)
#   tool/seed_test_videos.sh --big       # + une grosse (~120 Mo, 2 min 30)
#   tool/seed_test_videos.sh --clean     # supprime les vidéos de test
#
# La grosse vidéo dépasse 100 Mo : elle arrive en tête du tri.
set -euo pipefail

cd "$(dirname "$0")/.."

ACTION="${1:-}"
DIR="/sdcard/DCIM/TidyPicsVideos"

if command -v adb >/dev/null 2>&1; then
  ADB="$(command -v adb)"
elif [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
  ADB="$HOME/Library/Android/sdk/platform-tools/adb"
else
  echo "adb introuvable : installe les platform-tools du SDK Android." >&2
  exit 1
fi
if [ "$("$ADB" get-state 2>/dev/null)" != "device" ]; then
  echo "Aucun émulateur Android connecté. Lance-le d'abord." >&2
  exit 1
fi

rescan() {
  "$ADB" shell content call --uri content://media --method scan_volume \
    --arg external_primary >/dev/null
}

# Enregistre l'écran pendant <secondes> en faisant défiler les Réglages.
record() {
  local name="$1" seconds="$2" bitrate="$3"
  "$ADB" shell am start -a android.settings.SETTINGS >/dev/null
  (
    end=$((SECONDS + seconds))
    while [ $SECONDS -lt $end ]; do
      "$ADB" shell input swipe 500 1800 500 400 300
      "$ADB" shell input swipe 500 400 500 1800 300
    done
  ) &
  "$ADB" shell screenrecord --bit-rate "$bitrate" --time-limit "$seconds" \
    "$DIR/$name"
  wait
}

if [ "$ACTION" = "--clean" ]; then
  "$ADB" shell rm -rf "$DIR"
  rescan
  echo "Vidéos de test supprimées de l'émulateur."
  exit 0
fi

"$ADB" shell mkdir -p "$DIR"
for n in 1 2 3; do
  record "VID_test_$n.mp4" 4 4000000
done
if [ "$ACTION" = "--big" ]; then
  echo "Grosse vidéo : 2 min 30 d'enregistrement (~120 Mo, vérifie la place libre)…"
  record "VID_test_big.mp4" 150 40000000
fi
"$ADB" shell input keyevent HOME
rescan
"$ADB" shell ls -la "$DIR"
