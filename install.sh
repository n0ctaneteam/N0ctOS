#!/bin/env bash



export N0CTOS_DIR='/usr/share/N0ctOS'
export N0CTOS_BIN='/usr/share/N0ctOS/bin'
export N0CTOS_INSTALLERS='/usr/share/N0ctOS/installers'
export N0CTOS_CONFIGS='/usr/share/N0ctOS/configs'
export ETC_DIR="/etc"

export ISO_MODE=false


set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
notify(){ echo -e "\x1b[32;1;4m====== $@ ======\e[0m"; }

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
# Flags
# ---------------------------------------------------------------------------

# for arg in "$@"; do
#     case "$arg" in
#         --iso|-I)
#             export ISO_MODE=true
#             export ETC_DIR=~/Projects/N0ctOS-ISO/airootfs/etc
#             export N0CTOS_ISO_DIR=~/Projects/N0ctOS-ISO
#             export N0CTOS_ISO_ROOT="${N0CTOS_ISO_DIR}/airootfs"

#             export N0CTOS_DIR="${N0CTOS_ISO_ROOT}/usr/share/N0ctOS"
#             export N0CTOS_BIN="${N0CTOS_ISO_ROOT}/usr/share/N0ctOS/bin"
#             export N0CTOS_INSTALLERS="${N0CTOS_ISO_ROOT}/usr/share/N0ctOS/installers"
#             export N0CTOS_CONFIGS="${N0CTOS_ISO_ROOT}/usr/share/N0ctOS/configs"
#             ;;
#     esac
# done

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------
chmod +x $N0CTOS_INSTALLERS/*

source $N0CTOS_INSTALLERS/0-base.sh
source $N0CTOS_INSTALLERS/1-packages.sh
source $N0CTOS_INSTALLERS/2-non_repo_pkgs.sh
source $N0CTOS_INSTALLERS/3-dots_install.sh
