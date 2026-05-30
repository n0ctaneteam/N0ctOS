#!/bin/env bash

# if (( "$ISO_MODE" == true )); then
# 	exit 0
# fi

notify INSTALLING PKGS

# add as many package list files as needed
PKG_FILES=(
    "${N0CTOS_DIR}/--bare-pkgs--"
    "${N0CTOS_DIR}/--aur-pkgs--"
    "${N0CTOS_DIR}/--apps-pkgs--"
)

# ---------------------------------------------------------------------------
# Collect
# ---------------------------------------------------------------------------

PKGS=()

for FILE in "${PKG_FILES[@]}"; do

    # skip if file doesn't exist, warn and move on
    if [ ! -f "$FILE" ]; then
        warn "Package file not found, skipping: $FILE"
        continue
    fi

    info "Reading $FILE..."

    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        [[ "$line" =~ ^# ]] && continue
        PKGS+=("$line")
    done < "$FILE"

done

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

if [ ${#PKGS[@]} -eq 0 ]; then
    warn "No packages found across all files. Nothing to install."
    exit 0
fi

info "Installing ${#PKGS[@]} packages in parallel..."
info "Packages: ${PKGS[@]}"

if pkg -i "${PKGS[@]}"; then
    info "Done."
else
    warn "Some packages may have failed. Check output above."
fi