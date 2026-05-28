#!/bin/env bash


USR_CFG_DIR="~/.config"
ISO_CFG_DIR="~/Projects/N0ctOS-ISO/airootfs/etc/skel/.config"

# copy/link configs
if (( "$1" == "iso" )); then
  cp -rv /usr/share/N0ctOS/config/--home-defaults--/* ${ISO_CFG_DIR}
else
  cp -rv /usr/share/N0ctOS/config/--home-defaults--/* ${USR_CFG_DIR}
fi

# add bin to path


# link os release


#!/usr/bin/env bash

# setup_noctos.sh
# Run this once after installing N0ctOS to wire up the system properly.
# Needs root for the symlink step; the shell config edits touch user files only.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

NOCTOS_BIN="/usr/share/N0ctOS/bin"
NOCTOS_OSRELEASE="/usr/share/N0ctOS/os-release"
ETC_OSRELEASE="/etc/os-release"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '  [info]  %s\n' "$*"; }
warn()  { printf '  [warn]  %s\n' "$*" >&2; }
die()   { printf '  [error] %s\n' "$*" >&2; exit 1; }

# Appends a line to a file only if that exact line isn't already there.
# Usage: append_if_missing "line to add" /path/to/file
append_if_missing() {
    local line="$1"
    local file="$2"

    if grep -qxF "$line" "$file" 2>/dev/null; then
        info "Already present in $file, skipping."
    else
        printf '\n%s\n' "$line" >> "$file"
        info "Added to $file"
    fi
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

# Make sure the bin directory we're advertising actually exists.
# No point adding a ghost path to the user's shell.
[ -d "$NOCTOS_BIN" ] || die "$NOCTOS_BIN does not exist. Is N0ctOS installed?"

# The os-release file we're going to point at must exist too.
[ -f "$NOCTOS_OSRELEASE" ] || die "$NOCTOS_OSRELEASE not found."

# The symlink step writes to /etc, which requires root.
[ "$(id -u)" -eq 0 ] || die "Please run as root (sudo $0)."

# ---------------------------------------------------------------------------
# 1. PATH — bash
#    ~/.bashrc is for interactive non-login shells.
#    ~/.bash_profile catches login shells (ssh, tty, etc.).
#    We write to both so nothing slips through.
# ---------------------------------------------------------------------------

info "Configuring bash..."

BASH_LINE="export PATH=\"$NOCTOS_BIN:\$PATH\""

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

ZSH_LINE="export PATH=\"$NOCTOS_BIN:\$PATH\""

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
FISH_LINE="fish_add_path $NOCTOS_BIN"

mkdir -p "$FISH_CONFIG_DIR"
touch "$FISH_CONFIG"
append_if_missing "$FISH_LINE" "$FISH_CONFIG"

# ---------------------------------------------------------------------------
# 2. OS-RELEASE symlink
#    /etc/os-release is the standard place tools like hostnamectl, neofetch,
#    and various installers look to identify the distro. We replace whatever
#    is there with a symlink pointing at N0ctOS's own file.
#
#    We back up any existing file first so it's easy to undo.
# ---------------------------------------------------------------------------

info "Linking /etc/os-release..."

if [ -e "$ETC_OSRELEASE" ] && [ ! -L "$ETC_OSRELEASE" ]; then
    # It's a real file (not already a symlink) — back it up.
    BACKUP="${ETC_OSRELEASE}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$ETC_OSRELEASE" "$BACKUP"
    info "Existing $ETC_OSRELEASE backed up to $BACKUP"
elif [ -L "$ETC_OSRELEASE" ]; then
    # Already a symlink — remove it so we can point it at the right place.
    rm "$ETC_OSRELEASE"
fi

ln -s "$NOCTOS_OSRELEASE" "$ETC_OSRELEASE"
info "Symlink created: $ETC_OSRELEASE -> $NOCTOS_OSRELEASE"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

printf '\nAll done. Open a new shell (or run: source ~/.bashrc) to pick up the PATH change.\n'