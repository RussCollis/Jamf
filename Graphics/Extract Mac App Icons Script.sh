#!/bin/bash


: <<'SCRIPT_INFO'
=============================================================================
Extract Mac App Icons Script
=============================================================================
Description:   Extracts icons from macOS .app bundles, .pkg installers, and
               .dmg disk images into PNG format. Logs and summarizes
               extracted, skipped, and missing icons with detailed reporting.


Notes:         Scans multiple directories for applications and converts icons
               using sips. Creates organized output folders and generates
               comprehensive summary reports for tracking extraction results.

Requirements:  - sips (macOS native image tool)
               - pkgutil for .pkg file handling
               - hdiutil for .dmg file mounting
               - Read/write access to target directories

Output:        ~/Desktop/MacAppIcons/ (organized by source type)
Summary:       Icon extraction summary with detailed logs

=============================================================================
SCRIPT_INFO

# =============================================================
# Configuration Variables
# =============================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.4.1"


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

# === Output and Summary ===
OUTPUT_FOLDER="$HOME/Desktop/MacAppIcons"
mkdir -p "$OUTPUT_FOLDER"
SUMMARY_FILE="$OUTPUT_FOLDER/_${CURRENT_DATE}_icon_extraction_summary.txt"
> "$SUMMARY_FILE"

ICON_COUNT=0
ICON_COUNT_APP=0
ICON_COUNT_PKG=0
ICON_COUNT_DMG=0

SKIPPED_COUNT=0
MISSING_COUNT=0

# === Application directories ===
APP_DIRS=(
    "/Applications"
    "/System/Applications"
    "/Library/"
    "/System/Library/"
    "$HOME/Downloads/"
)

log "📦 Extracting icons from .app bundles..."
for DIR in "${APP_DIRS[@]}"; do
    while IFS= read -r APP; do
        APP_NAME=$(basename "$APP" .app)
        SAFE_APP_NAME=$(echo "$APP_NAME" | tr -cd '[:alnum:] _-')

        ICON_PATH=$(defaults read "$APP/Contents/Info.plist" CFBundleIconFile 2>/dev/null)
        [[ "$ICON_PATH" != *.icns ]] && ICON_PATH="${ICON_PATH}.icns"
        FULL_ICON_PATH="$APP/Contents/Resources/$ICON_PATH"

        APP_FOLDER="$OUTPUT_FOLDER/$SAFE_APP_NAME"
        OUTPUT_ICON="$APP_FOLDER/$SAFE_APP_NAME.png"

        if [[ -f "$OUTPUT_ICON" ]]; then
            log "⏩ Icon already exists, skipping: $SAFE_APP_NAME"
            echo "Skipped (duplicate): $SAFE_APP_NAME" >> "$SUMMARY_FILE"
            ((SKIPPED_COUNT++))
            continue
        fi

        if [[ -f "$FULL_ICON_PATH" ]]; then
            mkdir -p "$APP_FOLDER"
            sips -s format png "$FULL_ICON_PATH" --out "$OUTPUT_ICON" >/dev/null 2>&1
            ((ICON_COUNT++))
            ((ICON_COUNT_APP++))
            log "✅ Extracted icon for $SAFE_APP_NAME"
            echo "Extracted: $SAFE_APP_NAME" >> "$SUMMARY_FILE"
        else
            log "❌ Icon file not found for $SAFE_APP_NAME at $FULL_ICON_PATH"
            echo "Missing icon: $SAFE_APP_NAME" >> "$SUMMARY_FILE"
            ((MISSING_COUNT++))
        fi
    done < <(find "$DIR" -name "*.app" -maxdepth 2 2>/dev/null)
done

# === Extract from .pkg files ===
log "📦 Scanning for .pkg files..."
for DIR in "${APP_DIRS[@]}"; do
    while IFS= read -r PKG; do
        PKG_NAME=$(basename "$PKG" .pkg)
        SAFE_PKG_NAME=$(echo "$PKG_NAME" | tr -cd '[:alnum:] _-')
        TEMP_DIR="/tmp/pkg_extract_$SAFE_PKG_NAME"

        mkdir -p "$TEMP_DIR"
        log "Expanding $PKG to $TEMP_DIR"
        pkgutil --expand "$PKG" "$TEMP_DIR" 2>/dev/null || {
            log "❌ Failed to expand $PKG"
            rm -rf "$TEMP_DIR"
            continue
        }

        while IFS= read -r ICNS_FILE; do
            ICON_NAME=$(basename "$ICNS_FILE" .icns)
            OUTPUT_ICON="$OUTPUT_FOLDER/$SAFE_PKG_NAME/${ICON_NAME}.png"

            if [[ -f "$OUTPUT_ICON" ]]; then
                log "⏩ Icon already exists, skipping: $OUTPUT_ICON"
                echo "Skipped (duplicate): $OUTPUT_ICON" >> "$SUMMARY_FILE"
                ((SKIPPED_COUNT++))
                continue
            fi

            mkdir -p "$(dirname "$OUTPUT_ICON")"
            sips -s format png "$ICNS_FILE" --out "$OUTPUT_ICON" >/dev/null 2>&1
            ((ICON_COUNT++))
            ((ICON_COUNT_PKG++))
            log "✅ Extracted icon from $PKG: ${ICON_NAME}.png"
            echo "Extracted: $SAFE_PKG_NAME - ${ICON_NAME}" >> "$SUMMARY_FILE"
        done < <(find "$TEMP_DIR" -name "*.icns")

        rm -rf "$TEMP_DIR"
    done < <(find "$DIR" -name "*.pkg" -maxdepth 2 2>/dev/null)
done

# === Extract from .dmg files ===
log "📦 Scanning for .dmg files..."
for DIR in "${APP_DIRS[@]}"; do
    while IFS= read -r DMG; do
        DMG_NAME=$(basename "$DMG" .dmg)
        SAFE_DMG_NAME=$(echo "$DMG_NAME" | tr -cd '[:alnum:] _-')

        MOUNT_DIR=$(mktemp -d "/Volumes/${SAFE_DMG_NAME}_mnt_XXXX")
        log "Mounting $DMG..."

        hdiutil attach "$DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet
        if [[ $? -ne 0 ]]; then
            log "❌ Failed to mount $DMG"
            rm -rf "$MOUNT_DIR"
            continue
        fi

        while IFS= read -r ITEM; do
            if [[ "$ITEM" == *.app ]]; then
                APP_NAME=$(basename "$ITEM" .app)
                SAFE_APP_NAME=$(echo "$APP_NAME" | tr -cd '[:alnum:] _-')

                ICON_PATH=$(defaults read "$ITEM/Contents/Info.plist" CFBundleIconFile 2>/dev/null)
                [[ "$ICON_PATH" != *.icns ]] && ICON_PATH="${ICON_PATH}.icns"
                FULL_ICON_PATH="$ITEM/Contents/Resources/$ICON_PATH"

                APP_FOLDER="$OUTPUT_FOLDER/${SAFE_DMG_NAME}_${SAFE_APP_NAME}"
                OUTPUT_ICON="$APP_FOLDER/${SAFE_APP_NAME}.png"

                if [[ -f "$OUTPUT_ICON" ]]; then
                    log "⏩ Icon already exists, skipping: $OUTPUT_ICON"
                    echo "Skipped (duplicate): $OUTPUT_ICON" >> "$SUMMARY_FILE"
                    ((SKIPPED_COUNT++))
                    continue
                fi

                if [[ -f "$FULL_ICON_PATH" ]]; then
                    mkdir -p "$APP_FOLDER"
                    sips -s format png "$FULL_ICON_PATH" --out "$OUTPUT_ICON" >/dev/null 2>&1
                    ((ICON_COUNT++))
                    ((ICON_COUNT_DMG++))
                    log "✅ Extracted icon from $DMG: $SAFE_APP_NAME"
                    echo "Extracted: $SAFE_DMG_NAME - $SAFE_APP_NAME" >> "$SUMMARY_FILE"
                else
                    log "❌ No icon found in $ITEM"
                    echo "Missing icon: $ITEM" >> "$SUMMARY_FILE"
                    ((MISSING_COUNT++))
                fi

            elif [[ "$ITEM" == *.icns ]]; then
                ICON_NAME=$(basename "$ITEM" .icns)
                OUTPUT_ICON="$OUTPUT_FOLDER/${SAFE_DMG_NAME}/${ICON_NAME}.png"

                if [[ -f "$OUTPUT_ICON" ]]; then
                    log "⏩ Icon already exists, skipping: $OUTPUT_ICON"
                    echo "Skipped (duplicate): $OUTPUT_ICON" >> "$SUMMARY_FILE"
                    ((SKIPPED_COUNT++))
                    continue
                fi

                mkdir -p "$(dirname "$OUTPUT_ICON")"
                sips -s format png "$ITEM" --out "$OUTPUT_ICON" >/dev/null 2>&1
                ((ICON_COUNT++))
                ((ICON_COUNT_DMG++))
                log "✅ Extracted standalone .icns from $DMG: ${ICON_NAME}.png"
                echo "Extracted: $SAFE_DMG_NAME - ${ICON_NAME}" >> "$SUMMARY_FILE"
            fi
        done < <(find "$MOUNT_DIR" \( -name "*.app" -or -name "*.icns" \) 2>/dev/null)

        hdiutil detach "$MOUNT_DIR" -quiet
        rm -rf "$MOUNT_DIR"
    done < <(find "$DIR" -name "*.dmg" -maxdepth 2 2>/dev/null)
done

# === Final Summary ===
log "🧮 Summary:"
log "   ✔️ Total icons added from scan: $ICON_COUNT"
log "       - From .app bundles: $ICON_COUNT_APP"
log "       - From .pkg installers: $ICON_COUNT_PKG"
log "       - From .dmg images: $ICON_COUNT_DMG"
log "   ⏩ Icons skipped (duplicates): $SKIPPED_COUNT"
log "   ❌ Icons missing or not found: $MISSING_COUNT"

{
    echo "======== SUMMARY REPORT ========"
    echo "✔️  Total icons added from scan: $ICON_COUNT"
    echo "    - From .app bundles: $ICON_COUNT_APP"
    echo "    - From .pkg installers: $ICON_COUNT_PKG"
    echo "    - From .dmg images: $ICON_COUNT_DMG"
    echo "⏩ Icons skipped (duplicates): $SKIPPED_COUNT"
    echo "❌ Icons missing or not found: $MISSING_COUNT"
    echo "----------------------------------------"
    echo ""
    echo "Detailed log:"
    echo ""
    cat "$SUMMARY_FILE"
} > "${SUMMARY_FILE}.tmp" && mv "${SUMMARY_FILE}.tmp" "$SUMMARY_FILE"

log "📄 Summary report written to: $SUMMARY_FILE"