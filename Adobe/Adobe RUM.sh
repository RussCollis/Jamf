#!/bin/bash

# USAGE: Set FORCE_RUN=true to bypass epoch time checks and run immediately
# Example: FORCE_RUN=true ./adobe_rum_script.sh

dialogApp="/usr/local/bin/dialog"
userName=$(/bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}')
timeFile="/Users/$userName/Library/J24/Scripts/RUM/adobeRUM_epoch_times.txt"

# Check for force run parameter
FORCE_RUN=${FORCE_RUN:-false}

# Generate future epoch times (every 2 months for next 2 years)
generate_epoch_times() {
    local current_epoch=$(date +%s)
    local epochs=()
    
    # Start from current time and add 2-month intervals
    for i in {0..11}; do
        # Add 2 months (approximately 60 days) to current time
        local future_epoch=$((current_epoch + (i * 60 * 24 * 60 * 60)))
        epochs+=($future_epoch)
    done
    
    echo "${epochs[@]}"
}

# Set epoch times - use current time if forcing, otherwise use scheduled times
if [[ "$FORCE_RUN" == "true" ]]; then
    echo "FORCE_RUN enabled - script will run immediately"
    current_epoch=$(date +%s)
    # Set first epoch to current time minus 1 second to trigger immediate run
    initial_epoch_times=($((current_epoch - 1)) $(generate_epoch_times | cut -d' ' -f2-))
else
    # Use scheduled epoch times (every 2 months starting from current time)
    initial_epoch_times=($(generate_epoch_times))
fi

org="KPMG"

apptoupdate="adobeRUM"
maxdeferrals=2
# work out remaining deferrals"
appdomain="${org// /_}.$(echo $apptoupdate | awk -F '/' '{print $NF}')"

baseDialog="--title \"Adobe Suite Update\" \
--messagefont 'size=14' \
--icon \"/Users/$userName/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
--ontop \
--width 600 \
--height 400 \
--moveable \
--button1text \"Run\" \
--button2text \"Cancel Updates\" \
--quitkey x"

versionCheck () {
	echo "Checking for newer version..."
    dialog_string=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Library/Application\ Support/Dialog/Dialog.app/Contents/Info.plist)
	currentVersion=$(dialog --version | cut -c1-3)
	echo "Current Version: $currentVersion"
	latestVersionTested="2.5"
	if [[ $(echo "$currentVersion >= $latestVersionTested" | bc) -eq 1 ]]; then
    	echo "No Update Required Continuing..."
    else
        echo "Update Available, Downloading..."
        downloadDialog
    fi
}

downloadDialog () {
	dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/tags/v2.5.0" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
	expectedDialogTeamID="PWA5E9TQ59"
	# Create a temp directory
	workDir=$(/usr/bin/basename "$0")
	tempDir=$(/usr/bin/mktemp -d "/private/tmp/$workDir.XXXXXX")
	# Download latest version of swiftDialog
	/usr/bin/curl --location --silent "$dialogURL" -o "$tempDir/Dialog.pkg"
	# Verify download
	teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDir/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
	if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
		/usr/sbin/installer -pkg "$tempDir/Dialog.pkg" -target /
	else
		echo "Team ID verification failed, could not continue..."
		exit 6
	fi
	/bin/rm -Rf "$tempDir"
}

installAdobeRUM () {
	echo "Adobe Remote Update Manager not found. Installing..."
	
	# Create temp directory
	workDir=$(/usr/bin/basename "$0")
	tempDir=$(/usr/bin/mktemp -d "/private/tmp/$workDir.XXXXXX")
	
	# Try multiple Adobe RUM download URLs
	rumURLs=(
		"https://swupmf.adobe.com/webfeed/oobe/aam20/mac/AdobeRUMWithAUMID.dmg"
		"https://ccmdls.adobe.com/AdobeProducts/KCCC/CCD/5_3_1/osx10-64/ACCCx5_3_1_2_osx10-64.dmg"
		"https://download.adobe.com/pub/adobe/reader/mac/AcrobatDC/misc/RemoteUpdateManager.dmg"
	)
	
	download_success=false
	for rumURL in "${rumURLs[@]}"; do
		echo "Trying to download Adobe RUM from: $rumURL"
		
		if /usr/bin/curl --location --silent --fail --connect-timeout 30 --max-time 300 "$rumURL" -o "$tempDir/AdobeRUM.dmg"; then
			echo "Successfully downloaded from: $rumURL"
			download_success=true
			break
		else
			echo "Failed to download from: $rumURL"
		fi
	done
	
	if [[ "$download_success" == false ]]; then
		echo "ERROR: Failed to download Adobe RUM from all sources"
		echo "Please ensure internet connectivity and try again"
		echo "Alternative: Download RUM manually from Adobe Admin Console"
		rm -rf "$tempDir"
		return 1
	fi
	
	# Verify the downloaded file exists and has content
	if [[ ! -f "$tempDir/AdobeRUM.dmg" ]] || [[ ! -s "$tempDir/AdobeRUM.dmg" ]]; then
		echo "ERROR: Downloaded file is missing or empty"
		rm -rf "$tempDir"
		return 1
	fi
	
	# Mount the DMG
	echo "Mounting Adobe RUM installer..."
	mountPoint=$(/usr/bin/hdiutil attach "$tempDir/AdobeRUM.dmg" -nobrowse -quiet 2>/dev/null | grep "Volumes" | awk '{print $3}')
	
	if [[ -z "$mountPoint" ]]; then
		echo "Failed to mount Adobe RUM installer - trying to get more details..."
		echo "DMG file size: $(ls -lh "$tempDir/AdobeRUM.dmg" | awk '{print $5}')"
		echo "DMG file type: $(file "$tempDir/AdobeRUM.dmg")"
		
		# Try mounting with verbose output for debugging
		echo "Attempting manual mount with verbose output:"
		/usr/bin/hdiutil attach "$tempDir/AdobeRUM.dmg" -nobrowse
		
		rm -rf "$tempDir"
		return 1
	fi
	
	# Find and install the RUM package
	rumPkg=$(find "$mountPoint" -name "*.pkg" -type f | head -1)
	
	if [[ -n "$rumPkg" ]]; then
		echo "Installing Adobe RUM package: $rumPkg"
		/usr/sbin/installer -pkg "$rumPkg" -target /
		install_result=$?
		
		# Unmount and cleanup
		/usr/bin/hdiutil detach "$mountPoint" -quiet
		rm -rf "$tempDir"
		
		if [[ $install_result -eq 0 ]]; then
			echo "Adobe RUM installed successfully"
			# Verify installation
			if [[ -f "/usr/local/bin/RemoteUpdateManager" ]]; then
				echo "Adobe RUM installation verified"
				return 0
			else
				echo "Adobe RUM installation failed - RemoteUpdateManager not found after install"
				return 1
			fi
		else
			echo "Adobe RUM installation failed with exit code: $install_result"
			return 1
		fi
	else
		echo "No RUM package found in mounted DMG"
		echo "Contents of mounted DMG:"
		ls -la "$mountPoint"
		/usr/bin/hdiutil detach "$mountPoint" -quiet
		rm -rf "$tempDir"
		return 1
	fi
}

runAdobeUpdate () {
	echo "Starting Adobe Remote Update Manager..."
	
	# Check if RemoteUpdateManager exists, install if missing
	if [[ ! -f "/usr/local/bin/RemoteUpdateManager" ]]; then
		echo "Adobe Remote Update Manager not found at /usr/local/bin/RemoteUpdateManager"
		
		# Try alternative locations first
		alt_paths=(
			"/Applications/Utilities/Adobe Application Manager/core/RemoteUpdateManager"
			"/Applications/Utilities/Adobe Creative Cloud/Utils/Creative Cloud Uninstaller.app/Contents/Resources/RemoteUpdateManager"
			"/Library/Application Support/Adobe/Adobe Desktop Common/ADS/Adobe Desktop Service.app/Contents/Resources/RemoteUpdateManager"
		)
		
		rum_found=false
		for path in "${alt_paths[@]}"; do
			if [[ -f "$path" ]]; then
				echo "Found RemoteUpdateManager at: $path"
				echo "Creating symlink to /usr/local/bin/RemoteUpdateManager"
				mkdir -p "/usr/local/bin"
				ln -sf "$path" "/usr/local/bin/RemoteUpdateManager"
				rum_found=true
				break
			fi
		done
		
		# If not found in alternative locations, try Jamf policy first, then download
		if [[ "$rum_found" == false ]]; then
			echo "RemoteUpdateManager not found in standard locations."
			
			# Try to install via Jamf policy first
			echo "Attempting to install Adobe RUM via Jamf policy..."
			if command -v jamf >/dev/null 2>&1; then
				echo "Running Jamf policy to install Adobe RUM..."
				/usr/local/bin/jamf policy -event installRUM
				jamf_result=$?
				
				if [[ $jamf_result -eq 0 ]]; then
					echo "Jamf policy completed. Checking for RUM installation..."
					sleep 5  # Give time for installation to complete
					
					# Check if RUM is now available
					if [[ -f "/usr/local/bin/RemoteUpdateManager" ]]; then
						echo "Adobe RUM successfully installed via Jamf policy"
						rum_found=true
					else
						# Check alternative paths again after Jamf install
						for path in "${alt_paths[@]}"; do
							if [[ -f "$path" ]]; then
								echo "Found RemoteUpdateManager at: $path after Jamf install"
								echo "Creating symlink to /usr/local/bin/RemoteUpdateManager"
								mkdir -p "/usr/local/bin"
								ln -sf "$path" "/usr/local/bin/RemoteUpdateManager"
								rum_found=true
								break
							fi
						done
					fi
				else
					echo "Jamf policy failed with exit code: $jamf_result"
				fi
			else
				echo "Jamf binary not found - cannot run Jamf policy"
			fi
			
			# If Jamf policy didn't work, try direct download
			if [[ "$rum_found" == false ]]; then
				echo "Jamf installation failed or unavailable. Attempting direct download..."
				if ! installAdobeRUM; then
					echo "WARNING: Failed to install Adobe RUM via all methods."
					echo "Please ensure Adobe RUM is available via:"
					echo "1. Jamf policy with trigger 'installAdobeRUM'"
					echo "2. Adobe Creative Cloud Desktop installation"
					echo "3. Manual RUM deployment"
					
					# Show user dialog explaining the issue
					errorDialog="--title \"Adobe RUM Installation Failed\" \
					--messagefont 'size=14' \
					--message \"**Adobe Remote Update Manager could not be installed automatically.**\n\n**What happened:**\n• Jamf policy installation failed or unavailable\n• Direct download from Adobe failed\n• RUM not found in standard locations\n\n**To enable automatic updates, please:**\n• **Contact IT** to deploy Remote Update Manager\n• **Install Adobe Creative Cloud Desktop** app\n• **Check network connectivity** and try again\n\n**You can still update Adobe apps manually through:**\n• Creative Cloud Desktop app (Apps tab → Update)\n• Help → Updates within each Adobe app\" \
					--button1text \"OK\" \
					--infobuttontext \"Contact IT\" \
					--infobuttonaction \"https://kpmgenterprise.service-now.com/now/nav/ui/classic/params/target/incident.do%3Fsys_id%3D-1%26sys_is_list%3Dtrue%26sys_target%3Dincident%26sysparm_checked_items%3D%26sysparm_fixed_query%3D%26sysparm_group_sort%3D%26sysparm_list_css%3D%26sysparm_query%3Dassignment_group%253d6fd0b1ea1b1cb810a63cf9f5464bcba9%255estateNOT%2BIN6%252c7%252c8%26sysparm_referring_url%3Dincident_list.do%253fsysparm_query%253dassignment_group%25253D6fd0b1ea1b1cb810a63cf9f5464bcba9%25255EstateNOT%252bIN6%25252C7%25252C8%254099%2540sysparm_view%253dpowered%254099%2540sysparm_first_row%253d1%26sysparm_target%3D%26sysparm_view%3Dpowered\" \
					--icon \"SF=exclamationmark.triangle.fill,colour=red\" \
					--width 600 \
					--height 450 \
					--ontop"
					
					eval "$dialogApp $errorDialog"
					
					return 1
				else
					rum_found=true
				fi
			fi
		fi
	fi
	
	# Force quit Adobe applications before updating
	echo "Force quitting Adobe applications..."
	pkill -f "Adobe Creative Cloud"
	pkill -f "Adobe"
	pkill -f "Creative Cloud"
	sleep 5
	
	# Run Adobe Remote Update Manager
	echo "Running: /usr/local/bin/RemoteUpdateManager --action=install"
	/usr/local/bin/RemoteUpdateManager --action=install
	
	# Check exit status
	rum_exit_code=$?
	if [[ $rum_exit_code -eq 0 ]]; then
		echo "Adobe updates completed successfully"
		# Restart Creative Cloud Desktop app
		echo "Restarting Creative Cloud Desktop..."
		sleep 3
		open "/Applications/Adobe Creative Cloud/ACC/Creative Cloud.app" 2>/dev/null || \
		open "/Applications/Creative Cloud.app" 2>/dev/null
	else
		echo "Adobe Remote Update Manager failed with exit code: $rum_exit_code"
		case $rum_exit_code in
			1) echo "General error occurred" ;;
			2) echo "Invalid command line arguments" ;;
			3) echo "Application is running" ;;
			4) echo "Insufficient privileges" ;;
			*) echo "Unknown error code" ;;
		esac
		exit $rum_exit_code
	fi
}

runDialog () {
	deferrals=$(defaults read ${appdomain} deferrals 2>/dev/null || echo ${maxdeferrals})
	defaults write ${appdomain} deferrals -int ${deferrals}

	if [[ $deferrals -gt 0 ]]; then
		infobuttontext="Defer"
		timer=3600
		dialogContents="--message \" **WARNING**  <br>Open Adobe Applications Will Force Quit!  <br><br>You are required to ensure Adobe applications are running the latest minor version releases.  \n\nCheck for new updates by clicking 'Run Policy' \n\n**Remaining Deferrals: ${deferrals}**\n\n**Alternative:** You can update Adobe apps manually anytime through:<br>• Creative Cloud Desktop app (Apps tab → Update)<br>• Help → Updates within each Adobe app<br>• Contact IT for assistance\n\n\" \
		--timer $timer \
		--infobuttontext \"${infobuttontext}\" \
		--infobuttonaction \"cancel\""
	else
		infobuttontext="Max Deferrals Reached"
		dialogContents="--message \" **WARNING**  <br>Open Adobe Applications Will Force Quit!  <br><br>You are required to ensure Adobe applications are running the latest minor version releases.  \n\nCheck for new updates by clicking 'Run Policy' \n\n**Remaining Deferrals: ${deferrals}**\n\n**Alternative:** You can update Adobe apps manually anytime through:<br>• Creative Cloud Desktop app (Apps tab → Update)<br>• Help → Updates within each Adobe app<br>• Contact IT for assistance\n\n\" \
		--infobuttontext \"${infobuttontext}\""
	fi

	# Validate swiftDialog is installed
	if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
		echo "Dialog not found, installing..."
		downloadDialog
	else
		versionCheck
	fi

	echo "Prompting RUM Check"
	eval "$dialogApp $(echo $baseDialog $dialogContents)"
	dialog_exit_code=$?

	case $dialog_exit_code in
		0)  # Button 1 (Run Policy) clicked
			echo "User clicked 'Run Policy'. Continuing with Adobe update..."
			# cleanup deferral count
			defaults delete ${appdomain} deferrals 2>/dev/null
			
			# Remove the current epoch time since we're processing it
			if [[ ${#epoch_times[@]} -gt 0 ]]; then
				epoch_times=("${epoch_times[@]:1}")  # Remove first element
			fi
			
			# Run Adobe Remote Update Manager directly
			runAdobeUpdate
			;;
		2)  # Button 2 (Cancel Updates) clicked
			echo "User clicked 'Cancel Updates'. Permanently dismissing Adobe update prompts."
			
			# Set a permanent opt-out flag
			defaults write ${appdomain} user_opted_out -bool true
			defaults write ${appdomain} opt_out_date -string "$(date)"
			
			# Remove the current epoch time to prevent future prompts for this update
			if [[ ${#epoch_times[@]} -gt 0 ]]; then
				epoch_times=("${epoch_times[@]:1}")  # Remove first element
			fi
			
			# Clear any existing deferrals
			defaults delete ${appdomain} deferrals 2>/dev/null
			
			# Show confirmation dialog with manual update options and More Information button
			confirmationDialog="--title \"Adobe Updates Cancelled\" \
			--messagefont 'size=14' \
			--message \"**Adobe automatic updates have been permanently disabled.**\n\nYou can still update Adobe apps manually anytime through:\n\n• **Creative Cloud Desktop app** (Apps tab → Update All)\n\n• **Help → Updates** within each Adobe app (Photoshop, Illustrator, etc.)\n\n• **Contact IT** for assistance with updates\n\n• **Self Service** Reset the schedule via Adobe Updates Reset\n\n*Note: You are still responsible for keeping Adobe apps updated for security.*\" \
			--button1text \"OK\" \
					--infobuttontext \"Contact IT\" \
					--infobuttonaction \"https://kpmgenterprise.service-now.com/now/nav/ui/classic/params/target/incident.do%3Fsys_id%3D-1%26sys_is_list%3Dtrue%26sys_target%3Dincident%26sysparm_checked_items%3D%26sysparm_fixed_query%3D%26sysparm_group_sort%3D%26sysparm_list_css%3D%26sysparm_query%3Dassignment_group%253d6fd0b1ea1b1cb810a63cf9f5464bcba9%255estateNOT%2BIN6%252c7%252c8%26sysparm_referring_url%3Dincident_list.do%253fsysparm_query%253dassignment_group%25253D6fd0b1ea1b1cb810a63cf9f5464bcba9%25255EstateNOT%252bIN6%25252C7%25252C8%254099%2540sysparm_view%253dpowered%254099%2540sysparm_first_row%253d1%26sysparm_target%3D%26sysparm_view%3Dpowered\" \
			--icon \"/Users/$userName/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
			--width 550 \
			--height 450 \
			--ontop"
			
			eval "$dialogApp $confirmationDialog"
			
			echo "Adobe update permanently cancelled by user. User will not be prompted again."
			;;
		3|4)  # Info button (Defer) or Timer expired
			if [[ $deferrals -gt 0 ]]; then
				deferrals=$(( $deferrals - 1 ))
				defaults write ${appdomain} deferrals -int ${deferrals}
				echo "User deferred: $deferrals deferrals remaining"
			else
				echo "Max deferrals reached. User cannot defer further."
			fi
			;;
		*)  # Any other exit code (dialog closed, escaped, etc.)
			echo "Dialog dismissed with exit code: $dialog_exit_code"
			if [[ $deferrals -gt 0 ]]; then
				deferrals=$(( $deferrals - 1 ))
				defaults write ${appdomain} deferrals -int ${deferrals}
				echo "Treating as deferral: $deferrals deferrals remaining"
			fi
			;;
	esac
}

read_times() {
    epoch_times=()
    if [[ -f $timeFile ]] && [[ "$FORCE_RUN" != "true" ]]; then
        while IFS= read -r line; do
            # Skip empty lines
            [[ -n "$line" ]] && epoch_times+=("$line")
        done < "$timeFile"
    else
        if [[ "$FORCE_RUN" == "true" ]]; then
            echo "FORCE_RUN: Regenerating epoch times with immediate trigger"
        else
            echo "Creating time file at: $timeFile"
        fi
        mkdir -p "/Users/$userName/Library/J24/Scripts/RUM/"
        for epoch_time in "${initial_epoch_times[@]}"; do
            echo "$epoch_time" >> "$timeFile"
        done
        while IFS= read -r line; do
            [[ -n "$line" ]] && epoch_times+=("$line")
        done < "$timeFile"
    fi
}

write_times() {
    > "$timeFile"
    for epoch_time in "${epoch_times[@]}"; do
        echo "$epoch_time" >> "$timeFile"
    done
}

# Main execution
read_times

# Check if user has permanently opted out (unless forcing)
if [[ "$FORCE_RUN" != "true" ]]; then
    user_opted_out=$(defaults read ${appdomain} user_opted_out 2>/dev/null || echo "false")
    if [[ "$user_opted_out" == "true" ]]; then
        opt_out_date=$(defaults read ${appdomain} opt_out_date 2>/dev/null || echo "unknown")
        echo "User has permanently opted out of Adobe updates on: $opt_out_date"
        echo "No further update prompts will be shown."
        echo "Use FORCE_RUN=true to override and run anyway."
        exit 0
    fi
fi

current_time=$(date +%s)
echo "Current Epoch is $current_time: $(date)"

if [[ "$FORCE_RUN" == "true" ]]; then
    echo "FORCE_RUN: Bypassing epoch check and running immediately"
    runDialog
    write_times
elif [[ ${#epoch_times[@]} -gt 0 ]] && [[ ${epoch_times[0]} -le $current_time ]]; then
    echo "Scheduled Epoch Passed ${epoch_times[0]}: $(date -r ${epoch_times[0]})"
    echo "Notifying User"
    runDialog
    write_times  # Save updated times after processing
elif [[ ${#epoch_times[@]} -gt 0 ]]; then
    echo "Next Epoch is ${epoch_times[0]}: $(date -r ${epoch_times[0]})"
else
    echo "No more scheduled update times remaining"
fi