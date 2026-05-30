#!/bin/env bash

# ---------------------------------------------------------------------------
# 1. PATH — bash
#    ~/.bashrc is for interactive non-login shells.
#    ~/.bash_profile catches login shells (ssh, tty, etc.).
#    We write to both so nothing slips through.
# ---------------------------------------------------------------------------

info "Configuring bash..."

BASH_LINE="export PATH=\"$N0CTOS_BIN:\$PATH\""

for rc in "$HOME/.bashrc" "$HOME/.bash_profile"; do
    # Touch the file in case it doesn't exist yet (fresh user account).
    touch "$rc"
    append_if_missing "$BASH_LINE" "$rc"
done

# ---------------------------------------------------------------------------
# 1. PATH — zsh
#    zsh uses ~/.zshrc for interactive shells and ~/.zprofile for login shells.
#    Same two-file approach as bash above.
# ---------------------------------------------------------------------------

info "Configuring zsh..."

ZSH_LINE="export PATH=\"$N0CTOS_BIN:\$PATH\""

for rc in "$HOME/.zshrc" "$HOME/.zprofile"; do
    touch "$rc"
    append_if_missing "$ZSH_LINE" "$rc"
done

# ---------------------------------------------------------------------------
# 1. PATH — fish
#    fish doesn't source .bashrc or .zshrc. It has its own config file and
#    its own syntax for setting the PATH via fish_add_path (fish 3.2+).
#    fish_add_path is idempotent by default, so we don't need the
#    append_if_missing guard here, but we check anyway to keep the output tidy.
# ---------------------------------------------------------------------------

info "Configuring fish..."

FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONFIG="$FISH_CONFIG_DIR/config.fish"
FISH_LINE="fish_add_path $N0CTOS_BIN"

mkdir -p "$FISH_CONFIG_DIR"
touch "$FISH_CONFIG"
append_if_missing "$FISH_LINE" "$FISH_CONFIG"
