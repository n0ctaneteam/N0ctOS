#!/usr/bin/env bash


# ** THIS IS NOT A PART OF N0CTOS ITSELF **
# IT IS A DEV UTILITY
# IT HOT-RELOADS WAYBAR ON ANYCHANGE IN WAYBAR CONFIG DIRECTORY
# 
# WHILE RICING THE WAYBAR, JUST RUN THIS SCRIPT IN A TERMINAL IN BG.
# IT AUTO RUNS THE WAYBAR ON INIT.
# FOR GTK DEBUG, PLZ OPEN ANOTHER TERMINAL AND RUN "GTK_DEBUG=interactive waybar &"
# 
# THERE IS ALSO ANOTHER SCRIPT INSIDE THE CONFIG DIR "_SWITCHER_.SH"
# THAT AUTO LOADS THE THEME FILE THAT IS CHANGED AT THAT TIME
# THEME FILES CONTAIN THE SOURCE COLORS FOR THE WAYBAR...

export WAYBAR_DIR="$HOME/.config/waybar"

# Initial start (optional)
pkill waybar
waybar &

inotifywait -m -r \
  -e modify,create,delete,move \
  --format '%w%f' \
  "$WAYBAR_DIR" | while read -r file; do
    echo "Waybar config changed: $file"
    pkill waybar
    waybar &
    done
done