#!/bin/bash

: <<'SCRIPT_INFO'
=============================================================================
Convert ICNS to PNG Script
=============================================================================
Description:   Converts all .icns files in a specified folder to .png and
               deletes the originals using macOS native sips tool

Notes:         Uses sips (macOS native image tool) for conversion. Folder path
               is configurable via variable at top of script for easy
               customization without editing multiple locations.

Requirements:  - sips (macOS native image tool)
               - Read/write access to target directory

=============================================================================


SCRIPT_INFO

# =============================================================
# Configuration Variables
# =============================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.3.1"


# === Setup Logging ===
SCRIPT_NAME=$(basename "$0")
CURRENT_DATE=$(date '+%Y-%m-%d')
LOG_FILE="/var/tmp/com.kpmg.${SCRIPT_NAME%.*}_${CURRENT_DATE}.log"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log() {
    local MESSAGE="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$SCRIPT_NAME] $MESSAGE" | tee -a "$LOG_FILE"
}

# ------------------- USER-CONFIGURABLE VARIABLE ------------------------------

ICNS_FOLDER=""  # <--- Set this to your .icns directory

# =============================================================
# Main Script Logic
# =============================================================

main() {
    log "Starting Convert ICNS to PNG Script v$SCRIPT_VERSION"
    log "Target folder: $ICNS_FOLDER"
    
    # Validate the folder exists
    if [[ ! -d "$ICNS_FOLDER" ]]; then
        log "Error: '$ICNS_FOLDER' is not a valid directory."
        exit 1
    fi

    log "Script started: Scanning folder → $ICNS_FOLDER"

    # Find and convert each .icns file
    find "$ICNS_FOLDER" -type f -name "*.icns" | while read -r ICNS_FILE; do
        PNG_FILE="${ICNS_FILE%.icns}.png"

        log "Converting: $ICNS_FILE → $PNG_FILE"
        if sips -s format png "$ICNS_FILE" --out "$PNG_FILE" &>/dev/null; then
            log "Success: $PNG_FILE created"
            rm "$ICNS_FILE"
            log "Deleted: $ICNS_FILE"
        else
            log "Error: Failed to convert $ICNS_FILE"
        fi
    done

    log "Script completed successfully"
}

# =============================================================
# Script Entry Point
# =============================================================

main "$@"