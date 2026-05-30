#!/bin/env bash



# ---------------------------------------------------------------------------
# 2. OS-RELEASE symlink
#    ${ETC_DIR}/os-release is the standard place tools like hostnamectl, neofetch,
#    and various installers look to identify the distro. We replace whatever
#    is there with a symlink pointing at N0ctOS's own file.
#
#    We back up any existing file first so it's easy to undo.
# ---------------------------------------------------------------------------

info "Linking ${ETC_DIR}/os-release..."

if [ -e "${ETC_DIR}/os-release" ] && [ ! -L "${ETC_DIR}/os-release" ]; then
    # It's a real file (not already a symlink) — back it up.
    BACKUP="${ETC_DIR}/os-release.bak.$(date +%Y%m%d%H%M%S)"
    sudo mv "${ETC_DIR}/os-release" "$BACKUP"
    info "Existing ${ETC_DIR}/os-release backed up to $BACKUP"
elif [ -L "${ETC_DIR}/os-release" ]; then
    # Already a symlink — remove it so we can point it at the right place.
    sudo rm "${ETC_DIR}/os-release"
fi

sudo ln -s "${N0CTOS_DIR}/os-release" "${ETC_DIR}/os-release"
info "Symlink created: ${ETC_DIR}/os-release -> ${N0CTOS_DIR}/os-release"
