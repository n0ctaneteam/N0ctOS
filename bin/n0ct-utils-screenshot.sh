#!/usr/bin/env bash

set -e

# -------- Config --------
export DEFAULT_TARGET_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DEFAULT_TARGET_DIR"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
FILE_NAME="$DEFAULT_TARGET_DIR/screenshot_$TIMESTAMP.png"

N0CT_SCREENSHOT_OPEN_SATTY_EDITOR=false
export GRIMBLAST_EDITOR=satty

# -------- Flags --------
for arg in "$@"; do
  case "$arg" in
    --edit) N0CT_SCREENSHOT_OPEN_SATTY_EDITOR=true ;;
    --screen) N0CT_SCREENSHOT_MODE=screen ;;
  esac
done


# -------- ScreenShot Function --------
grimblast --notify --expire-time 1300 --freeze --wait 0.13 --filetype png copysave area

# -------- Notification --------
notify-send \
  -a "Screenshot" \
  -i "$FILE_NAME" \
  "Screenshot captured" \
  "Saved & Copied Screenshot !!"

done