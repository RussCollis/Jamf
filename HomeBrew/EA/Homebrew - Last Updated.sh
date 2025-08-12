#!/bin/bash


: <<'SCRIPT_INFO'
=============================================================================
Homebrew Packages Extension Attribute
=============================================================================
Description:   Reports all Homebrew packages and casks installed on the
                    system including versions, outdated items, and deprecated
                    packages in JSON format for Jamf inventory collection

Author:        Unknown
Version:       1.0.0

Notes:         Scans for Homebrew installations across common paths for both
                    Intel and Apple Silicon Macs. Provides comprehensive package
                    inventory with versioning, update status, and deprecation
                    information formatted for Jamf Pro consumption.

Requirements:  - Homebrew (if installed)
                    - jq (optional, provides enhanced JSON formatting)
                    - Read access to Homebrew directories

Output:        JSON formatted data containing packages, casks, versions,
                    outdated items, deprecated packages, and summary statistics

=============================================================================

=============================================================================
Changelog
=============================================================================
    [2025-08-08] v1.0.0 - Initial version with standardized header format
=============================================================================
SCRIPT_INFO

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

# Function to get brew packages as JSON array with line breaks
get_brew_packages() {
    local brew_cmd="$1"
    local packages
    
    # Get list of installed packages with versions
    packages=$("$brew_cmd" list --formula --versions 2>/dev/null | while IFS= read -r line; do
        if [ -n "$line" ]; then
            package_name=$(echo "$line" | awk '{print $1}')
            package_version=$(echo "$line" | awk '{print $2}')
            printf '        {"name":"%s","version":"%s","type":"formula"},\n' "$package_name" "$package_version"
        fi
    done)
    
    # Remove trailing comma and newline, wrap in array with proper formatting
    if [ -n "$packages" ]; then
        packages="[\n${packages%,*}\n    ]"
        printf "$packages"
    else
        echo "[]"
    fi
}

# Function to get brew casks as JSON array with line breaks
get_brew_casks() {
    local brew_cmd="$1"
    local casks
    
    # Get list of installed casks with versions
    casks=$("$brew_cmd" list --cask --versions 2>/dev/null | while IFS= read -r line; do
        if [ -n "$line" ]; then
            cask_name=$(echo "$line" | awk '{print $1}')
            cask_version=$(echo "$line" | awk '{print $2}')
            # Handle cases where version might be empty
            if [ -z "$cask_version" ]; then
                cask_version="unknown"
            fi
            printf '        {"name":"%s","version":"%s","type":"cask"},\n' "$cask_name" "$cask_version"
        fi
    done)
    
    # Remove trailing comma and newline, wrap in array with proper formatting
    if [ -n "$casks" ]; then
        casks="[\n${casks%,*}\n    ]"
        printf "$casks"
    else
        echo "[]"
    fi
}

# Function to get outdated packages and casks
get_outdated_items() {
    local brew_cmd="$1"
    local outdated_packages outdated_casks
    
    # Get outdated formulae
    outdated_packages=$("$brew_cmd" outdated --formula --json 2>/dev/null | jq -c '[.[] | {name: .name, current_version: .installed_versions[0], latest_version: .current_version, type: "formula"}]' 2>/dev/null || echo "[]")
    
    # Get outdated casks
    outdated_casks=$("$brew_cmd" outdated --cask --json 2>/dev/null | jq -c '[.[] | {name: .name, current_version: .installed_versions[0], latest_version: .current_version, type: "cask"}]' 2>/dev/null || echo "[]")
    
    # Combine arrays if jq is available
    if command -v jq >/dev/null 2>&1; then
        # Format with line breaks for better readability
        echo "$outdated_packages $outdated_casks" | jq -s 'add' | sed 's/\[/[\n        /g; s/\]/\n    ]/g; s/},{/},\n        {/g'
    else
        # Fallback without jq - simpler format with line breaks
        local outdated_simple
        outdated_simple=$("$brew_cmd" outdated --formula 2>/dev/null | while IFS= read -r line; do
            if [ -n "$line" ]; then
                printf '        {"name":"%s","type":"formula"},\n' "$line"
            fi
        done)
        
        outdated_simple+=$("$brew_cmd" outdated --cask 2>/dev/null | while IFS= read -r line; do
            if [ -n "$line" ]; then
                printf '        {"name":"%s","type":"cask"},\n' "$line"
            fi
        done)
        
        if [ -n "$outdated_simple" ]; then
            printf "[\n%s\n    ]" "${outdated_simple%,*}"
        else
            echo "[]"
        fi
    fi
}

# Function to get deprecated casks
get_deprecated_casks() {
    local brew_cmd="$1"
    local deprecated_items=""
    
    # Get list of installed casks
    local installed_casks
    installed_casks=$("$brew_cmd" list --cask 2>/dev/null)
    
    if [ -z "$installed_casks" ]; then
        echo "[]"
        return
    fi
    
    # Check each installed cask for deprecation
    while IFS= read -r cask_name; do
        if [ -n "$cask_name" ]; then
            # Use brew info to check if cask is deprecated
            local cask_info
            cask_info=$("$brew_cmd" info --cask "$cask_name" 2>/dev/null)
            
            if echo "$cask_info" | grep -q "deprecated\|disabled"; then
                # Extract deprecation reason if available
                local reason
                reason=$(echo "$cask_info" | grep -i "deprecated\|disabled" | head -n1 | sed 's/^[[:space:]]*//')
                if [ -z "$reason" ]; then
                    reason="Deprecated"
                fi
                
                deprecated_items="${deprecated_items}        {\"name\":\"$cask_name\",\"type\":\"cask\",\"reason\":\"$reason\"},\n"
            fi
        fi
    done <<< "$installed_casks"
    
    # Format as JSON array with line breaks
    if [ -n "$deprecated_items" ]; then
        printf "[\n%s\n    ]" "${deprecated_items%,*}"
    else
        echo "[]"
    fi
}

# Main execution
main() {
    # Try to find Homebrew installation
    brew_path=$(get_brew_path)
    
    if [ $? -ne 0 ]; then
        # Homebrew not found
        echo "<r>Homebrew not installed</r>"
        exit 0
    fi
    
    # Update brew to get latest package info (suppress output)
    "$brew_path" update >/dev/null 2>&1
    
    # Get Homebrew version for context
    brew_version=$("$brew_path" --version 2>/dev/null | head -n 1 | cut -d' ' -f2)
    
    # Get packages and casks
    packages=$(get_brew_packages "$brew_path")
    casks=$(get_brew_casks "$brew_path")
    
    # Get outdated items
    outdated_items=$(get_outdated_items "$brew_path")
    
    # Get deprecated casks
    deprecated_items=$(get_deprecated_casks "$brew_path")
    
    # Force default values if functions return empty
    outdated_items=${outdated_items:-"[]"}
    deprecated_items=${deprecated_items:-"[]"}
    
    # Ensure arrays have valid values - fix empty output issue
    if [ -z "$outdated_items" ] || [ "$outdated_items" = "null" ] || [ "$outdated_items" = "" ]; then
        outdated_items="[]"
    fi
    
    if [ -z "$deprecated_items" ] || [ "$deprecated_items" = "null" ] || [ "$deprecated_items" = "" ]; then
        deprecated_items="[]"
    fi
    
    # Count totals with forced defaults
    package_count=$(echo "$packages" | jq '. | length' 2>/dev/null || echo "0")
    cask_count=$(echo "$casks" | jq '. | length' 2>/dev/null || echo "0")
    package_count=${package_count:-0}
    cask_count=${cask_count:-0}
    outdated_count=0
    deprecated_count=0
    
    # Get counts from arrays - handle the case where jq isn't available or arrays are malformed
    if command -v jq >/dev/null 2>&1 && [ "$outdated_items" != "[]" ]; then
        outdated_count=$(echo "$outdated_items" | jq '. | length' 2>/dev/null || echo "0")
    fi
    
    if command -v jq >/dev/null 2>&1 && [ "$deprecated_items" != "[]" ]; then
        deprecated_count=$(echo "$deprecated_items" | jq '. | length' 2>/dev/null || echo "0")
    fi
    
    # Ensure all counts are numeric
    outdated_count=${outdated_count:-0}
    deprecated_count=${deprecated_count:-0}
    
    # Final validation - make sure they're actually numbers
    case "$outdated_count" in
        ''|*[!0-9]*) outdated_count=0 ;;
    esac
    
    case "$deprecated_count" in
        ''|*[!0-9]*) deprecated_count=0 ;;
    esac
    
    # Get last update check time - force a value
    last_update_check="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Create final JSON output
    result=$(cat <<EOF
{
    "homebrew_version": "$brew_version",
    "brew_path": "$brew_path",
    "package_count": $package_count,
    "cask_count": $cask_count,
    "outdated_count": $outdated_count,
    "deprecated_count": $deprecated_count,
    "packages": $packages,
    "casks": $casks,
    "outdated_items": $outdated_items,
    "deprecated_items": $deprecated_items,
    "total_items": $((package_count + cask_count)),
    "last_update_check": "$last_update_check",
    "scan_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)
    
    # Output for Jamf
    echo "<result>$result</result>"
}

# Run the main function
main