#!/usr/bin/env bash

echo -e "\n\n\\e[32m=== (re)Launching N0ctBar... ===\\e[0m"
echo "> killing existing waybar and ags processes..."
killall waybar & disown

sleep 0.3
echo "> existing processes killed successfully"
echo -e "\n\n\\e[32m== Relaunching N0ctBar... ===\\e[0m"
echo "> starting waybar..."
runapp waybar --config "$HOME/.config/N0ctBar/waybar/config.jsonc" --style "$HOME/.config/N0ctBar/waybar/style.css" &
disown
echo "> waybar started successfully"
