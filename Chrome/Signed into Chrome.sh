#!/bin/bash

<<'SCRIPT_INFO'
# -----------------------------------------------------------------------------
Script:        get_chrome_email.sh
Description:   Extracts email addresses from Chrome browser preferences files
Version:       1.0.0
Last Updated:  2025-08-02
Author:        Russell Collis - KPMG

Changelog:
    [2025-08-02] v1.0.0 - initial: First version
# -----------------------------------------------------------------------------
SCRIPT_INFO

# Script configuration and constants
readonly SCRIPT_NAME="get_chrome_email"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.0.0"

# Set error handling
set -euo pipefail

# Main script logic
main() {
    email=$(grep -h '"email"' ~/Library/Application\ Support/Google/Chrome/*/Preferences | sed -n 's/.*"email"[ ]*:[ ]*"\([^"]*\)".*/\1/p')
    
    echo "<result>$email</result>"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi