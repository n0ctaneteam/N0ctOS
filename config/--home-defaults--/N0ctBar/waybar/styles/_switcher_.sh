#!/bin/env bash
target=$1

if [[ -n "${target}" ]]; then
	cp $HOME/.config/N0ctBar/waybar/styles/"$target".css $HOME/.config/N0ctBar/waybar/style.css
else
  # !! TESTING ONLY !! #
  # !! LOADS THE FILE TO STYLE.CSS, WHICH IS EDITED !! #
  inotifywait -m -r \
  -e modify,create,delete,move \
  --format '%w%f' \
  "$HOME"/.config/N0ctBar/waybar/styles | while read -r file; do
    cp $file $HOME/.config/N0ctBar/waybar/style.css
    echo "Waybar STYLE changed: $file"
    n0ctbar
    done
fi
