#!/usr/bin/env bash

# update.sh
# Checks the remote N0ctOS repo for updates on the current branch
# and pulls them into /usr/share/N0ctOS if anything changed.
# Usage: ./update.sh
# Run as root or with sudo.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

N0CTOS_DIR="/usr/share/N0ctOS"
REMOTE="https://github.com/n0ctaneteam/N0ctOS"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '  [info]  %s\n' "$*"; }
warn()  { printf '  [warn]  %s\n' "$*" >&2; }
die()   { printf '  [error] %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || die "Please run as root (sudo $0)."

[ -d "$N0CTOS_DIR/.git" ] || die "$N0CTOS_DIR is not a git repo. Is N0ctOS installed?"

command -v git &>/dev/null || die "git is not installed."

# ---------------------------------------------------------------------------
# Detect current branch
# ---------------------------------------------------------------------------

cd "$N0CTOS_DIR"

BRANCH=$(git rev-parse --abbrev-ref HEAD)

info "Current branch: $BRANCH"
info "Remote: $REMOTE"

# ---------------------------------------------------------------------------
# Fetch remote and check for changes
# ---------------------------------------------------------------------------

info "Fetching remote..."

git fetch origin "$BRANCH" --quiet

LOCAL=$(git rev-parse HEAD)
REMOTE_HEAD=$(git rev-parse "origin/$BRANCH")

if [ "$LOCAL" = "$REMOTE_HEAD" ]; then
    info "Already up to date. Nothing to do."
    exit 0
fi

# show a short log of what's incoming before pulling
info "Updates available:"
echo ""
git log --oneline HEAD.."origin/$BRANCH"
echo ""

# ---------------------------------------------------------------------------
# Pull
# ---------------------------------------------------------------------------

info "Pulling updates from $REMOTE on branch: $BRANCH..."

git pull origin "$BRANCH" --ff-only

info "N0ctOS updated successfully on branch: $BRANCH"