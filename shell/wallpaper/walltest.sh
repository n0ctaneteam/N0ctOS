#!/usr/bin/env bash

set -e

# ============================================================
# CONFIG
# ============================================================

PATHS=(
    "$HOME/MY_FILES/331d344c012c1ff4307858f8c9f38706.gif"
    "$HOME/MY_FILES/u3632899868_a_vector-style_anime_illustration_of_adult_Levi_Ack_077b5d77-07ea-4500-a1c4-fda3006d5dd8.png"
    "/home/n0ctanedev/Pictures/wallpapers/Comets-of-that-night.jpg"
    "/home/n0ctanedev/Downloads/galaxy-eyes.1920x1080.mp4"
    "/home/n0ctanedev/Downloads/midnight-skyline.1920x1080.mp4"
    "/home/n0ctanedev/Downloads/gojo-blue-eyes-jjk.1920x1080.mp4"
    "/home/n0ctanedev/Downloads/5baac92b61_tanjiro-kamado-crimson-moon-live-wallpaper-wallsflow-com.mp4"
    "/home/n0ctanedev/Downloads/0a721ebb28_zero-two-toyota-gr-86-4k-live.mp4"
)

# Command executed after selecting a path
PATH_COMMAND=(qs -p /usr/share/N0ctOS/shell ipc call n0ctos-wall set eDP-1)

# Command executed with the entered word
WORD_COMMAND=(qs -p /usr/share/N0ctOS/shell ipc call n0ctos-transition set)


# ============================================================
# CHECK DEPENDENCIES
# ============================================================

if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is required."
    echo "Install it with:"
    echo "  sudo pacman -S fzf"
    exit 1
fi


# ============================================================
# MAIN LOOP
# ============================================================

while true; do
    clear

    # Run fzf with filtering disabled (--disabled) so typing text in the prompt 
    # acts strictly as entering a transition word without filtering the path list.
    SELECTION="$(
        printf '%s\n' "${PATHS[@]}" |
        fzf \
            --disabled \
            --prompt='Transition Word > ' \
            --height=60% \
            --layout=reverse \
            --border \
            --header='↑↓ Choose Path | Type Word | Enter Apply | Esc Exit' \
            --print-query \
            --no-multi
    )" || exit 0

    # fzf returns the typed query on line 1 and selected path on line 2
    WORD="$(echo "$SELECTION" | head -n1)"
    SELECTED_PATH="$(echo "$SELECTION" | tail -n1)"

    # Exit if no path was highlighted/selected
    [[ -z "$SELECTED_PATH" ]] && exit 0

    # 1. Apply transition word if entered
    if [[ -n "$WORD" ]]; then
        echo "Setting transition word: $WORD"
        "${WORD_COMMAND[@]}" "$WORD"
    fi

    # 2. Apply path command
    echo "Setting path: $SELECTED_PATH"
    "${PATH_COMMAND[@]}" "$SELECTED_PATH"

    sleep 0.3
done