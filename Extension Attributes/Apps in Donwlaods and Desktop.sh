#!/bin/bash

#!/bin/bash

: <<'SCRIPT_INFO'
# -----------------------------------------------------------------------------
	Script:        HomeFolderAppNamesEA.sh
	Description:   Lists .app bundle names found in users' Downloads and Desktop folders
	Version:       1.4.0
	Last Updated:  2025-07-30
	Author:        Russell Collis 
	Requirements:  None
	Changelog:
		[2025-07-30] v1.4.0 - Limited scan to Downloads and Desktop folders only
# -----------------------------------------------------------------------------
SCRIPT_INFO

APP_NAMES=()

for USER_HOME in /Users/*; do
	USERNAME=$(basename "$USER_HOME")
	
	# Skip shared/system accounts
	if [[ "$USERNAME" == "Shared" ]] || [[ "$USERNAME" == ".localized" ]] || [[ "$USERNAME" == ".log" ]]; then
		continue
	fi
	
	for FOLDER in "Downloads" "Desktop"; do
		SCAN_PATH="${USER_HOME}/${FOLDER}"
		if [[ -d "$SCAN_PATH" ]]; then
			FOUND_APPS=$(find "$SCAN_PATH" -type d -name "*.app" -prune 2>/dev/null)
			if [[ -n "$FOUND_APPS" ]]; then
				while IFS= read -r APP; do
					APP_NAME=$(basename "$APP")
					if [[ ! " ${APP_NAMES[*]} " =~ " ${APP_NAME} " ]]; then
						APP_NAMES+=("$APP_NAME")
					fi
				done <<< "$FOUND_APPS"
			fi
		fi
	done
	
	# -------------------------------------------------------------------------
	# v1.3.0 - Previously scanned entire user home folder:
	#
	# if [[ -d "$USER_HOME" ]]; then
	#   FOUND_APPS=$(find "$USER_HOME" -type d -name "*.app" -prune 2>/dev/null)
	#   if [[ -n "$FOUND_APPS" ]]; then
	#     while IFS= read -r APP; do
	#       APP_NAME=$(basename "$APP")
	#       if [[ ! " ${APP_NAMES[*]} " =~ " ${APP_NAME} " ]]; then
	#         APP_NAMES+=("$APP_NAME")
	#       fi
	#     done <<< "$FOUND_APPS"
	#   fi
	# fi
	# -------------------------------------------------------------------------
	
done

if [[ ${#APP_NAMES[@]} -gt 0 ]]; then
	printf "<result>\n%s\n</result>\n" "$(printf "%s\n" "${APP_NAMES[@]}")"
else
	echo "<result>None</result>"
fi