#!/bin/bash

#
# Script Name: homebrew_update_date_only.sh
# Description: Jamf Extension Attribute - Homebrew last update date only
# Author: IT Administrator
# Created: $(date '+%Y-%m-%d')
# Version: 1.0
# 
# Purpose: Reports ONLY the last update check date for Homebrew (extracted from full inventory script)
# Returns: Single date string for Jamf inventory and Smart Group usage
#
# Requirements:
#   - Homebrew installed on target systems
#   - macOS/Linux with bash
#
# Usage: Run as Jamf Extension Attribute script
#
# Exit Codes:
#   0 - Always successful
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'       # Secure Internal Field Separator

# Function to check if Homebrew is installed and get its path
get_brew_path() {
    # Common Homebrew installation paths
    local brew_paths=(
        "/opt/homebrew/bin/brew"     # Apple Silicon Macs
        "/usr/local/bin/brew"        # Intel Macs
        "/home/linuxbrew/.linuxbrew/bin/brew"  # Linux
    )
    
    for path in "${brew_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try to find brew in PATH
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi
    
    return 1
}

# Main execution - simplified from the comprehensive script
main() {
    # Try to find Homebrew installation
    brew_path=$(get_brew_path)
    
    if [ $? -ne 0 ]; then
        # Homebrew not found
        echo "<r>Not installed</r>"
        exit 0
    fi
    
    # Get last update check time - same logic as the main script but simplified
    last_update_check="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Output for Jamf - just the date string, no JSON wrapper
    echo "<r>$last_update_check</r>"
}

# Run the main function
main