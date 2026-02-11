#!/bin/env bash
target=$1

cp $HOME/.config/waybar/themes/"$target".css $HOME/.config/waybar/theme.css



# !! TESTING ONLY !! #
# !! LOADS THE FILE TO THEME.CSS, WHICH IS EDITED !! #
inotifywait -m -r \
  -e modify,create,delete,move \
  --format '%w%f' \
  "$HOME"/.config/waybar/themes | while read -r file; do
    cp $file $HOME/.config/waybar/theme.css
    echo "Waybar THEME changed: $file"
done