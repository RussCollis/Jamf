#!/bin/bash

: <<'SCRIPT_INFO'
=============================================================================
Homebrew Version Extension Attribute
=============================================================================
Description:   Jamf Extension Attribute that reports only the Homebrew
               version number or installation status. Provides simple version
               string for Smart Group filtering and version compliance
               tracking across the KPMG macOS fleet.
Author:        Russell Collis

Requirements:  macOS/Linux with bash
Output:        Single version string (e.g., "4.6.3") or "Not installed"
=============================================================================
SCRIPT_INFO

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

# Main execution
main() {
    # Try to find Homebrew installation
    brew_path=$(get_brew_path)
    
    if [ $? -ne 0 ]; then
        # Homebrew not found
        echo "<r>Not installed</r>"
        exit 0
    fi
    
    # Get Homebrew version
    brew_version=$("$brew_path" --version 2>/dev/null | head -n 1 | cut -d' ' -f2)
    
    # Ensure we got a version, fallback if needed
    if [ -z "$brew_version" ]; then
        brew_version="Unknown"
    fi
    
    # Output for Jamf - just the version string
    echo "<r>$brew_version</r>"
}

# Run the main function
main