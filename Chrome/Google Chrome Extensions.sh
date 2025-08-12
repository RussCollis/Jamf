#!/bin/bash

#
# Script Name: homebrew_update_upgrade.sh
# Description: Jamf Policy Script - Update Homebrew and upgrade all packages/casks
# Author: IT Administrator
# Created: $(date '+%Y-%m-%d')
# Version: 1.0
# 
# Purpose: Updates Homebrew repository and upgrades all installed packages and casks
# Usage: Deploy as Jamf Policy script for maintenance automation
#
# Requirements:
#   - Homebrew installed on target systems
#   - Sufficient disk space for upgrades
#   - Network connectivity for downloads
#   - Admin privileges for some cask upgrades
#
# Exit Codes:
#   0 - Success (all operations completed)
#   1 - Homebrew not found
#   2 - Update failed
#   3 - Upgrade failed
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'       # Secure Internal Field Separator

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

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

# Function to run brew update
update_homebrew() {
    local brew_cmd="$1"
    
    log_message "Starting Homebrew repository update..."
    
    if "$brew_cmd" update; then
        log_message "✅ Homebrew repository updated successfully"
        return 0
    else
        log_message "❌ Failed to update Homebrew repository"
        return 1
    fi
}

# Function to upgrade packages (formulae)
upgrade_packages() {
    local brew_cmd="$1"
    
    log_message "Checking for package upgrades..."
    
    # Check if there are outdated packages
    local outdated_packages
    outdated_packages=$("$brew_cmd" outdated --formula 2>/dev/null)
    
    if [ -n "$outdated_packages" ]; then
        log_message "Found outdated packages:"
        echo "$outdated_packages" | while IFS= read -r package; do
            log_message "  - $package"
        done
        
        log_message "Starting package upgrades..."
        if "$brew_cmd" upgrade --formula; then
            log_message "✅ All packages upgraded successfully"
            return 0
        else
            log_message "❌ Some package upgrades failed"
            return 1
        fi
    else
        log_message "✅ All packages are already up to date"
        return 0
    fi
}

# Function to upgrade casks
upgrade_casks() {
    local brew_cmd="$1"
    
    log_message "Checking for cask upgrades..."
    
    # Check if there are outdated casks
    local outdated_casks
    outdated_casks=$("$brew_cmd" outdated --cask 2>/dev/null)
    
    if [ -n "$outdated_casks" ]; then
        log_message "Found outdated casks:"
        echo "$outdated_casks" | while IFS= read -r cask; do
            log_message "  - $cask"
        done
        
        log_message "Starting cask upgrades..."
        # Use --greedy to upgrade casks that don't have version strings
        if "$brew_cmd" upgrade --cask --greedy; then
            log_message "✅ All casks upgraded successfully"
            return 0
        else
            log_message "⚠️  Some cask upgrades may have failed (this is common for GUI apps)"
            # Don't return error for casks as some may require user interaction
            return 0
        fi
    else
        log_message "✅ All casks are already up to date"
        return 0
    fi
}

# Function to cleanup after upgrades
cleanup_homebrew() {
    local brew_cmd="$1"
    
    log_message "Running Homebrew cleanup..."
    
    if "$brew_cmd" cleanup; then
        log_message "✅ Homebrew cleanup completed"
        
        # Show space saved
        local cleanup_output
        cleanup_output=$("$brew_cmd" cleanup -n 2>/dev/null | grep -i "would remove\|would delete" | wc -l)
        if [ "$cleanup_output" -gt 0 ]; then
            log_message "🗑️  Cleaned up old versions and downloads"
        fi
        return 0
    else
        log_message "⚠️  Cleanup had issues but continuing"
        return 0
    fi
}

# Function to generate summary report
generate_summary() {
    local brew_cmd="$1"
    
    log_message "Generating post-upgrade summary..."
    
    # Count current packages
    local package_count cask_count
    package_count=$("$brew_cmd" list --formula | wc -l | tr -d ' ')
    cask_count=$("$brew_cmd" list --cask | wc -l | tr -d ' ')
    
    # Check remaining outdated items
    local remaining_outdated
    remaining_outdated=$("$brew_cmd" outdated 2>/dev/null | wc -l | tr -d ' ')
    
    log_message "📊 SUMMARY:"
    log_message "   Packages installed: $package_count"
    log_message "   Casks installed: $cask_count"
    log_message "   Items still outdated: $remaining_outdated"
    
    if [ "$remaining_outdated" -eq 0 ]; then
        log_message "🎉 All Homebrew items are now up to date!"
    else
        log_message "⚠️  Some items may still need updates (check manually)"
    fi
}

# Main execution
main() {
    log_message "🍺 Starting Homebrew update and upgrade process..."
    
    # Find Homebrew installation
    brew_path=$(get_brew_path)
    
    if [ $? -ne 0 ]; then
        log_message "❌ Homebrew not found on this system"
        exit 1
    fi
    
    log_message "Found Homebrew at: $brew_path"
    
    # Step 1: Update Homebrew repository
    if ! update_homebrew "$brew_path"; then
        log_message "❌ Failed to update Homebrew repository"
        exit 2
    fi
    
    # Step 2: Upgrade packages (formulae)
    if ! upgrade_packages "$brew_path"; then
        log_message "❌ Package upgrade failed"
        exit 3
    fi
    
    # Step 3: Upgrade casks
    if ! upgrade_casks "$brew_path"; then
        log_message "⚠️  Cask upgrade had issues but continuing"
    fi
    
    # Step 4: Cleanup old versions
    cleanup_homebrew "$brew_path"
    
    # Step 5: Generate summary
    generate_summary "$brew_path"
    
    log_message "🎉 Homebrew update and upgrade process completed successfully!"
    exit 0
}

# Run the main function
main