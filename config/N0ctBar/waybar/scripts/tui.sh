#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <tui-command> [args...]"
  exit 1
fi

kitty \
  --class kitty-float \
  --title "Floating TUI" \
  --placement=center \
  --override initial_window_width=900 \
  --override initial_window_height=600 \
  --single-instance \
  --detach \
  "$@"