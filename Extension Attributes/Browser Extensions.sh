#!/bin/bash

# Jamf Extension Attribute to report all browser extensions
# Covers Chrome, Edge, Firefox, and Safari extensions

result=""
extensions_found=false

# Function to get extension info from Chrome/Edge manifest
get_chromium_extension_info() {
    local manifest_path="$1"
    local browser_name="$2"
    local extension_dir="$3"
    
    if [[ -f "$manifest_path" ]]; then
        python3 -c "
import json
import sys
import os
try:
    with open('$manifest_path', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    name = data.get('name', 'Unknown')
    version = data.get('version', 'Unknown')
    
    # Handle localization for Edge extensions
    if name.startswith('__MSG_'):
        # Try to find localized name
        locale_key = name.replace('__MSG_', '').replace('__', '')
        
        # Look for _locales directory
        locales_dir = os.path.join('$extension_dir', '_locales')
        if os.path.exists(locales_dir):
            # Try common locales
            for locale in ['en', 'en_US', 'en_GB']:
                locale_file = os.path.join(locales_dir, locale, 'messages.json')
                if os.path.exists(locale_file):
                    try:
                        with open(locale_file, 'r', encoding='utf-8') as lf:
                            locale_data = json.load(lf)
                        if locale_key in locale_data:
                            name = locale_data[locale_key].get('message', name)
                            break
                        # Also try common variations
                        for key_variant in [locale_key, locale_key.lower(), 'appName', 'extensionName', 'app_name']:
                            if key_variant in locale_data:
                                name = locale_data[key_variant].get('message', name)
                                break
                        if not name.startswith('__MSG_'):
                            break
                    except:
                        continue
        
        # If still not found, clean up the key
        if name.startswith('__MSG_'):
            name = locale_key.replace('_', ' ').title()
    
    print(f'[$browser_name] {name} (v{version})')
except Exception as e:
    print(f'[$browser_name] Unknown Extension')
" 2>/dev/null
    fi
}

# Function to add extension to result
add_extension() {
    local extension_info="$1"
    
    if [[ -n "$extension_info" ]]; then
        if [[ "$extensions_found" == false ]]; then
            result="$extension_info"
            extensions_found=true
        else
            result="$result
$extension_info"
        fi
    fi
}

# Check for extensions in all user profiles
for user_home in /Users/*; do
    if [[ -d "$user_home" && ! "$user_home" == *"Shared"* && ! "$user_home" == *".localized"* ]]; then
        username=$(basename "$user_home")
        
        # Skip system accounts
        if [[ "$username" == "root" || "$username" == "daemon" || "$username" == "Guest" ]]; then
            continue
        fi
        
        # Chrome Extensions
        chrome_extensions_path="$user_home/Library/Application Support/Google/Chrome/Default/Extensions"
        if [[ -d "$chrome_extensions_path" ]]; then
            for extension_dir in "$chrome_extensions_path"/*; do
                if [[ -d "$extension_dir" ]]; then
                    extension_id=$(basename "$extension_dir")
                    if [[ ${#extension_id} -eq 32 ]]; then
                        for version_dir in "$extension_dir"/*; do
                            if [[ -d "$version_dir" ]]; then
                                manifest_file="$version_dir/manifest.json"
                                extension_info=$(get_chromium_extension_info "$manifest_file" "Chrome" "$version_dir")
                                if [[ -n "$extension_info" ]]; then
                                    add_extension "$extension_info"
                                    break
                                fi
                            fi
                        done
                    fi
                fi
            done
        fi
        
        # Microsoft Edge Extensions
        edge_extensions_path="$user_home/Library/Application Support/Microsoft Edge/Default/Extensions"
        if [[ -d "$edge_extensions_path" ]]; then
            for extension_dir in "$edge_extensions_path"/*; do
                if [[ -d "$extension_dir" ]]; then
                    extension_id=$(basename "$extension_dir")
                    if [[ ${#extension_id} -eq 32 ]]; then
                        for version_dir in "$extension_dir"/*; do
                            if [[ -d "$version_dir" ]]; then
                                manifest_file="$version_dir/manifest.json"
                                extension_info=$(get_chromium_extension_info "$manifest_file" "Edge" "$version_dir")
                                if [[ -n "$extension_info" ]]; then
                                    add_extension "$extension_info"
                                    break
                                fi
                            fi
                        done
                    fi
                fi
            done
        fi
        
        # Firefox Extensions
        firefox_profile_path="$user_home/Library/Application Support/Firefox/Profiles"
        if [[ -d "$firefox_profile_path" ]]; then
            for profile_dir in "$firefox_profile_path"/*; do
                if [[ -d "$profile_dir" ]]; then
                    extensions_json="$profile_dir/extensions.json"
                    if [[ -f "$extensions_json" ]]; then
                        firefox_extensions=$(python3 -c "
import json
import sys
try:
    with open('$extensions_json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    addons = data.get('addons', [])
    extensions = []
    for addon in addons:
        if addon.get('type') == 'extension' and addon.get('active', False):
            name = addon.get('defaultLocale', {}).get('name', addon.get('id', 'Unknown'))
            version = addon.get('version', 'Unknown')
            extensions.append(f'[Firefox] {name} (v{version})')
    for ext in extensions:
        print(ext)
except:
    pass
" 2>/dev/null)
                        
                        if [[ -n "$firefox_extensions" ]]; then
                            while IFS= read -r extension_info; do
                                add_extension "$extension_info"
                            done <<< "$firefox_extensions"
                        fi
                    fi
                fi
            done
        fi
        
        # Safari Extensions (macOS 10.14+)
        safari_extensions_path="$user_home/Library/Safari/Extensions"
        if [[ -d "$safari_extensions_path" ]]; then
            for extension_dir in "$safari_extensions_path"/*; do
                if [[ -d "$extension_dir" ]]; then
                    extension_name=$(basename "$extension_dir" .safariextension)
                    info_plist="$extension_dir/Info.plist"
                    if [[ -f "$info_plist" ]]; then
                        version=$(defaults read "$info_plist" CFBundleVersion 2>/dev/null || echo "Unknown")
                        display_name=$(defaults read "$info_plist" CFBundleDisplayName 2>/dev/null || echo "$extension_name")
                        add_extension "[Safari] $display_name (v$version)"
                    else
                        add_extension "[Safari] $extension_name"
                    fi
                fi
            done
        fi
        
        # Safari App Extensions (macOS 10.14+)
        safari_app_extensions=$(python3 -c "
import plistlib
import os
try:
    safari_prefs = '$user_home/Library/Preferences/com.apple.Safari.plist'
    if os.path.exists(safari_prefs):
        with open(safari_prefs, 'rb') as f:
            prefs = plistlib.load(f)
        extensions = prefs.get('ExtensionsEnabled', {})
        for ext_id, enabled in extensions.items():
            if enabled:
                print(f'[Safari] {ext_id}')
except:
    pass
" 2>/dev/null)
        
        if [[ -n "$safari_app_extensions" ]]; then
            while IFS= read -r extension_info; do
                add_extension "$extension_info"
            done <<< "$safari_app_extensions"
        fi
    fi
done

# Output result
if [[ "$extensions_found" == false ]]; then
    echo "<result>No browser extensions found</result>"
else
    echo "<result>$result</result>"
fi

exit 0