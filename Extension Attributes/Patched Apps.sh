#!/bin/bash


# This script shows AAP status and recently updated apps filtered against Installomator labels.
# Make sure to set the Extension Attribute Data Type to "String".


# Path to the App Auto Patch working folder:
AAP_folder="/Library/Management/AppAutoPatch"
# Path to the local property list file:
AAP_plist="${AAP_folder}/xyz.techitout.appAutoPatch" # No trailing ".plist"

# Check if the App Auto Patch preference file exists
if [[ -f "${AAP_plist}.plist" ]]; then
	# Get the completion status
	AAPPatchingCompletionStatus=$(defaults read "${AAP_plist}" AAPPatchingCompletionStatus 2> /dev/null)
	
#	# Handle empty/null status
#	if [[ -z "${AAPPatchingCompletionStatus}" ]]; then
#		AAPPatchingCompletionStatus="Not Set"
	#	fi
#	
	# Start building result
#	result="${AAPPatchingCompletionStatus}
#"
	
	# Download Installomator.sh file to get actual app labels
	installomator_file="/tmp/installomator_$$"
	if curl -s "https://raw.githubusercontent.com/Installomator/Installomator/main/Installomator.sh" -o "${installomator_file}" 2>/dev/null; then
		# Extract app labels from the Installomator.sh file (look for case statements)
		valid_apps_file="/tmp/valid_apps_$$"
		grep -E "^\s*[a-zA-Z0-9][a-zA-Z0-9_-]*\)" "${installomator_file}" | sed 's/[[:space:]]*\([^)]*\)).*/\1/' | tr '[:upper:]' '[:lower:]' | sort -u > "${valid_apps_file}"
		
		# Look for apps modified in the last 7 days
		current_time=$(date +%s)
		seven_days_ago=$((current_time - 604800))
		
		# Create temporary file to store app data for sorting
		temp_file="/tmp/aap_apps_$$"
		
		# Check /Applications for recently modified apps
		while IFS= read -r -d '' app_path; do
			if [[ -d "${app_path}" ]]; then
				app_name=$(basename "${app_path}" .app)
				app_mod_time=$(stat -f %m "${app_path}" 2>/dev/null)
				
				if [[ -n "${app_mod_time}" ]] && [[ ${app_mod_time} -gt ${seven_days_ago} ]]; then
					# Check if app was installed from App Store
					info_plist="${app_path}/Contents/Info.plist"
					is_app_store_app="false"
					
					if [[ -f "${info_plist}" ]]; then
						# Check for App Store receipt
						receipt_path="${app_path}/Contents/_MASReceipt/receipt"
						if [[ -f "${receipt_path}" ]]; then
							is_app_store_app="true"
						fi
						
						# Also check for LSApplicationCategoryType indicating App Store app
						app_category=$(defaults read "${info_plist}" LSApplicationCategoryType 2>/dev/null)
						if [[ "${app_category}" == "public.app-category.app-store" ]]; then
							is_app_store_app="true"
						fi
					fi
					
					# Skip App Store apps
					if [[ "${is_app_store_app}" == "false" ]]; then
						# Check if app is user-installed (not admin/system installed)
						is_user_installed="false"
						
						# Check ownership - user-installed apps often have user ownership
						app_owner=$(stat -f %Su "${app_path}" 2>/dev/null)
						if [[ "${app_owner}" != "root" ]] && [[ "${app_owner}" != "_appstore" ]] && [[ "${app_owner}" != "admin" ]]; then
							is_user_installed="true"
						fi
						
						# Check permissions - system/admin apps usually have restricted permissions
						app_perms=$(stat -f %Mp%Lp "${app_path}" 2>/dev/null)
						if [[ "${app_perms}" =~ ^777$ ]]; then
							# User-writable permissions suggest user installation
							is_user_installed="true"
						fi
						
						# Skip user-installed apps
						if [[ "${is_user_installed}" == "false" ]]; then
							# Check if app is in Installomator labels
							app_name_clean=$(echo "${app_name}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
							
							# Try multiple matching patterns against Installomator labels
							is_valid_app="false"
							
							# Direct exact match
							if grep -q "^${app_name_clean}$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
								# Try common variations
							elif grep -q "^${app_name_clean}app$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
								# Try without spaces/punctuation
							elif grep -q "^$(echo "${app_name}" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]//g' | sed 's/[^a-z0-9]//g')$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
								# Try with common suffixes removed
							elif grep -q "^$(echo "${app_name_clean}" | sed 's/app$//' | sed 's/pro$//')$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
							fi
							
							# Only include apps that are in Installomator
							if [[ "${is_valid_app}" == "true" ]]; then
								# Convert timestamp to readable date
								app_mod_date=$(date -r "${app_mod_time}" "+%d-%m-%Y %H:%M:%S" 2>/dev/null)
								
								# Get app version from Info.plist
								app_version=""
								if [[ -f "${info_plist}" ]]; then
									# Try CFBundleShortVersionString first, then CFBundleVersion
									app_version=$(defaults read "${info_plist}" CFBundleShortVersionString 2>/dev/null)
									if [[ -z "${app_version}" ]]; then
										app_version=$(defaults read "${info_plist}" CFBundleVersion 2>/dev/null)
									fi
								fi
								
								# Default to "Unknown" if no version found
								if [[ -z "${app_version}" ]]; then
									app_version="Unknown"
								fi
								
								# Determine installation method
								install_method=""
								
								# Check for package installation indicators
								if [[ -f "/private/var/db/receipts/${app_name}.pkg.bom" ]] || [[ -f "/Library/Receipts/${app_name}.pkg" ]]; then
									install_method=" (pkg-installed)"
								elif find /private/var/db/receipts -name "*$(echo "${app_name}" | tr '[:upper:]' '[:lower:]')*" 2>/dev/null | head -1 | grep -q .; then
									install_method=" (pkg-installed)"
									# Check for admin user installation via ownership
								elif [[ "${app_owner}" == "admin" ]] || [[ "${app_owner}" == "root" ]]; then
									# Check if installed by admin user (not system process)
									if [[ -f "${app_path}/Contents/MacOS/"* ]]; then
										binary_owner=$(stat -f %Su "${app_path}/Contents/MacOS/"* 2>/dev/null | head -1)
										if [[ "${binary_owner}" != "root" ]] && [[ "${binary_owner}" != "_appstore" ]]; then
											install_method=" (admin-installed)"
										fi
									fi
								fi
								
								# If no specific method detected but owned by admin/root, assume system install
								if [[ -z "${install_method}" ]] && [[ "${app_owner}" == "admin" || "${app_owner}" == "root" ]]; then
									install_method=" (system-installed)"
								fi
								
								# Write to temp file: timestamp|app_name|version|formatted_date|install_method
								echo "${app_mod_time}|${app_name}|${app_version}|${app_mod_date}|${install_method}" >> "${temp_file}"
							fi
						fi
					fi
				fi
			fi
		done < <(find /Applications -maxdepth 1 -name "*.app" -print0 2>/dev/null)
		
		# Check /Applications/Utilities as well
		while IFS= read -r -d '' app_path; do
			if [[ -d "${app_path}" ]]; then
				app_name=$(basename "${app_path}" .app)
				app_mod_time=$(stat -f %m "${app_path}" 2>/dev/null)
				
				if [[ -n "${app_mod_time}" ]] && [[ ${app_mod_time} -gt ${seven_days_ago} ]]; then
					# Check if app was installed from App Store
					info_plist="${app_path}/Contents/Info.plist"
					is_app_store_app="false"
					
					if [[ -f "${info_plist}" ]]; then
						# Check for App Store receipt
						receipt_path="${app_path}/Contents/_MASReceipt/receipt"
						if [[ -f "${receipt_path}" ]]; then
							is_app_store_app="true"
						fi
						
						# Also check for LSApplicationCategoryType indicating App Store app
						app_category=$(defaults read "${info_plist}" LSApplicationCategoryType 2>/dev/null)
						if [[ "${app_category}" == "public.app-category.app-store" ]]; then
							is_app_store_app="true"
						fi
					fi
					
					# Skip App Store apps
					if [[ "${is_app_store_app}" == "false" ]]; then
						# Check if app is user-installed (not admin/system installed)
						is_user_installed="false"
						
						# Check ownership - user-installed apps often have user ownership
						app_owner=$(stat -f %Su "${app_path}" 2>/dev/null)
						if [[ "${app_owner}" != "root" ]] && [[ "${app_owner}" != "_appstore" ]] && [[ "${app_owner}" != "admin" ]]; then
							is_user_installed="true"
						fi
						
						# Check permissions - system/admin apps usually have restricted permissions
						app_perms=$(stat -f %Mp%Lp "${app_path}" 2>/dev/null)
						if [[ "${app_perms}" =~ ^777$ ]]; then
							# User-writable permissions suggest user installation
							is_user_installed="true"
						fi
						
						# Skip user-installed apps
						if [[ "${is_user_installed}" == "false" ]]; then
							# Check if app is in Installomator labels
							app_name_clean=$(echo "${app_name}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
							
							# Try multiple matching patterns against Installomator labels
							is_valid_app="false"
							
							# Direct exact match
							if grep -q "^${app_name_clean}$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
								# Try common variations
							elif grep -q "^${app_name_clean}app$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
								# Try without spaces/punctuation
							elif grep -q "^$(echo "${app_name}" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]//g' | sed 's/[^a-z0-9]//g')$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
								# Try with common suffixes removed
							elif grep -q "^$(echo "${app_name_clean}" | sed 's/app$//' | sed 's/pro$//')$" "${valid_apps_file}" 2>/dev/null; then
								is_valid_app="true"
							fi
							
							# Only include apps that are in Installomator
							if [[ "${is_valid_app}" == "true" ]]; then
								# Convert timestamp to readable date
								app_mod_date=$(date -r "${app_mod_time}" "+%d-%m-%Y %H:%M:%S" 2>/dev/null)
								
								# Get app version from Info.plist
								app_version=""
								if [[ -f "${info_plist}" ]]; then
									# Try CFBundleShortVersionString first, then CFBundleVersion
									app_version=$(defaults read "${info_plist}" CFBundleShortVersionString 2>/dev/null)
									if [[ -z "${app_version}" ]]; then
										app_version=$(defaults read "${info_plist}" CFBundleVersion 2>/dev/null)
									fi
								fi
								
								# Default to "Unknown" if no version found
								if [[ -z "${app_version}" ]]; then
									app_version="Unknown"
								fi
								
								# Write to temp file: timestamp|app_name|version|formatted_date
								echo "${app_mod_time}|${app_name}|${app_version}|${app_mod_date}" >> "${temp_file}"
							fi
						fi
					fi
				fi
			fi
		done < <(find /Applications/Utilities -maxdepth 1 -name "*.app" -print0 2>/dev/null)
		
		# Sort by app name (alphabetically) and build result
		if [[ -f "${temp_file}" ]]; then
			while IFS='|' read -r timestamp app_name app_version app_mod_date install_method; do
				result="${result}${app_name} (v${app_version})${install_method}: ${app_mod_date}
"
			done < <(sort -t'|' -k2,2 "${temp_file}")
			
			# Clean up temp file
			rm -f "${temp_file}"
		fi
		
		# Clean up downloaded files
		rm -f "${installomator_file}" "${valid_apps_file}"
		
	else
		result="${result}Could not download Installomator script
"
	fi
	
	# Remove trailing newline and output
	result=$(echo "${result}" | sed '$s/$//')
	
	if [[ "${result}" == "${AAPPatchingCompletionStatus}" ]]; then
		echo "<result>${AAPPatchingCompletionStatus}
No recent Installomator-supported app updates found</result>"
	else
		echo "<result>${result}</result>"
	fi
else
	echo "<result>No AAP preference file.</result>"
fi

exit 0