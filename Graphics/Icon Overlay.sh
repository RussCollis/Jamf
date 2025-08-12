#!/bin/bash

# -----------------------------------------------------------------------------
# Script:        Overlay Icon Composer
# Description:   Prompts the user to select a base icon and a badge icon,
#                resizes the badge to 50% of the base icon's width/height,
#                and composites it in the bottom-right corner (with slight offset).
#                The final output is saved to the Desktop and named using the
#                input file names (e.g., Safari_with_BetaBadge.png).
# Requirements:  https://imagemagick.org/script/download.php
# Version:       1.1.0
# Last Updated:  2024-07-09

# Changelog:
#   [2025-07-09] v1.1.0 - Removed logging for silent operation
# -----------------------------------------------------------------------------

choose_file() {
    osascript <<EOF
        try
            set chosenFile to POSIX path of (choose file with prompt "$1")
            return chosenFile
        on error
            return ""
        end try
EOF
}

BASE=$(choose_file "Select the base icon image")
[[ -z "$BASE" ]] && exit 1

BADGE=$(choose_file "Select the badge icon image")
[[ -z "$BADGE" ]] && exit 1

# --- Extract file names WITHOUT extensions ---
BASE_NAME=$(basename "$BASE" | sed 's/\.[^.]*$//')
BADGE_NAME=$(basename "$BADGE" | sed 's/\.[^.]*$//')

# --- Compose output file name ---
OUTPUT="$HOME/Desktop/${BASE_NAME}_with_${BADGE_NAME}.png"

# --- Get dimensions of base image ---
read BASE_WIDTH BASE_HEIGHT < <(magick identify -format "%w %h" "$BASE")

# --- Resize badge to 50% ---
BADGE_WIDTH=$(( BASE_WIDTH / 2 ))
BADGE_HEIGHT=$(( BASE_HEIGHT / 2 ))
OFFSET="-25-25"

# --- Composite badge onto base icon ---
magick "$BASE" \
  \( "$BADGE" -resize "${BADGE_WIDTH}x${BADGE_HEIGHT}" \) \
  -gravity southeast -geometry "$OFFSET" -composite "$OUTPUT"

exit 0