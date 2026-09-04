#!/usr/bin/env bash
# update.sh
# Checks the remote N0ctOS repo for updates on the configured branch
# and pulls them into /usr/share/N0ctOS if anything changed.
# Usage: ./update.sh
# Run as root or with sudo.
set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
N0CTOS_DIR="/usr/share/N0ctOS"
REMOTE="https://github.com/n0ctaneteam/N0ctOS"
USER_CONFIG="${HOME}/.config/N0ctOS/config.jsonc"

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
# Read _branch from ~/.config/N0ctOS/config.jsonc
# Strips // and /* */ comments before parsing with grep.
# ---------------------------------------------------------------------------
read_config_branch() {
    [ -f "$USER_CONFIG" ] || die "Config file not found: $USER_CONFIG"

    # Strip single-line comments (// ...) and inline block comments (/* ... */)
    # then extract the value of "_branch"
    local branch
    branch=$(sed 's|//.*||g; s|/\*.*\*/||g' "$USER_CONFIG" \
        | grep -Po '"_branch"\s*:\s*"\K[^"]+')

    [ -n "$branch" ] || die "Could not read \"_branch\" from $USER_CONFIG"
    printf '%s' "$branch"
}

# ---------------------------------------------------------------------------
# Detect branch from config
# ---------------------------------------------------------------------------
BRANCH=$(read_config_branch)
info "Branch (from config): $BRANCH"
info "Remote: $REMOTE"

# ---------------------------------------------------------------------------
# Checkout the configured branch if not already on it
# ---------------------------------------------------------------------------
cd "$N0CTOS_DIR"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    info "Switching from '$CURRENT_BRANCH' to '$BRANCH'..."
    git fetch origin "$BRANCH" --quiet
    git checkout "$BRANCH" --quiet
fi

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

# Show a short log of what's incoming before pulling
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