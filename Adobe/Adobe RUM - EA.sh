#!/bin/bash

#!/bin/bash

# Adobe RUM Reset Script
# Re-enables automatic Adobe updates for users who previously opted out
# Usage: ./reset_adobe_updates.sh [username]

dialogApp="/usr/local/bin/dialog"

# Configuration - must match your main script
org="KPMG"
apptoupdate="adobeRUM"
appdomain="${org// /_}.$(echo $apptoupdate | awk -F '/' '{print $NF}')"

# Get target username
if [[ -n "$1" ]]; then
	targetUser="$1"
	echo "Resetting Adobe updates for specified user: $targetUser"
else
	targetUser=$(/bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}')
	echo "Resetting Adobe updates for current console user: $targetUser"
fi

# Validate user exists
if [[ -z "$targetUser" || "$targetUser" == "loginwindow" ]]; then
	echo "ERROR: No valid user found. Please specify a username:"
	echo "Usage: $0 [username]"
	exit 1
fi

timeFile="/Users/$targetUser/Library/J24/Scripts/RUM/adobeRUM_epoch_times.txt"

# Swift Dialog functions
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

versionCheck () {
	echo "Checking for newer version..."
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

ensure_dialog() {
	# Validate swiftDialog is installed
	if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
		echo "Dialog not found, installing..."
		downloadDialog
	else
		versionCheck
	fi
}

show_status_dialog() {
	local user_opted_out=$(sudo -u "$targetUser" defaults read "$appdomain" user_opted_out 2>/dev/null || echo "false")
	local opt_out_date=$(sudo -u "$targetUser" defaults read "$appdomain" opt_out_date 2>/dev/null || echo "not set")
	local deferrals=$(sudo -u "$targetUser" defaults read "$appdomain" deferrals 2>/dev/null || echo "not set")
	local time_file_exists="No"
	local epoch_count="0"
	local next_update="None scheduled"
	
	if [[ -f "$timeFile" ]]; then
		time_file_exists="Yes"
		epoch_count=$(wc -l < "$timeFile" 2>/dev/null || echo "0")
		if [[ $epoch_count -gt 0 ]]; then
			next_epoch=$(head -1 "$timeFile" 2>/dev/null)
			if [[ -n "$next_epoch" && "$next_epoch" != "" ]]; then
				next_update=$(date -r $next_epoch 2>/dev/null || echo 'Invalid date')
			fi
		fi
	fi
	
	statusDialog="--title \"Adobe Update Status\" \
	--messagefont 'size=14' \
	--message \"**Current Adobe Update Status for: $targetUser**\n\n**Opted Out:** $user_opted_out\n**Opt-out Date:** $opt_out_date\n**Remaining Deferrals:** $deferrals\n**Time File Exists:** $time_file_exists\n**Scheduled Updates:** $epoch_count\n**Next Update:** $next_update\n\n\" \
	--button1text \"OK\" \
	--icon \"/Users/$targetUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
	--width 500 \
	--height 400 \
	--ontop"
	
	eval "$dialogApp $statusDialog"
}

show_reset_confirmation() {
	local user_opted_out=$(sudo -u "$targetUser" defaults read "$appdomain" user_opted_out 2>/dev/null || echo "false")
	
	if [[ "$user_opted_out" == "true" ]]; then
		local opt_out_date=$(sudo -u "$targetUser" defaults read "$appdomain" opt_out_date 2>/dev/null || echo "unknown")
		
		confirmDialog="--title \"Re-enable Adobe Updates?\" \
		--messagefont 'size=14' \
		--message \"**User $targetUser has opted out of automatic Adobe updates**\n\n**Opt-out Date:** $opt_out_date\n\n**Re-enabling will:**\n• Allow automatic update prompts to appear again\n• Reset deferral count to 2\n\n• Create a new update schedule\n\n**The user can still:**\n• Defer updates when prompted\n\n• Opt out again if desired\n\n• Update manually through Creative Cloud\n\nDo you want to re-enable automatic Adobe updates for this user?\" \
		--button1text \"Re-enable\" \
		--button2text \"Cancel\" \
		--icon \"/Users/$targetUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
		--width 550 \
		--height 450 \
		--ontop"
		
		eval "$dialogApp $confirmDialog"
		return $?
	else
		confirmDialog="--title \"Reset Adobe Update Schedule?\" \
		--messagefont 'size=14' \
		--message \"**User $targetUser has NOT opted out of automatic updates**\n\n**Current Status:** Update prompts are enabled\n\n**Resetting will:**\n• Clear any existing deferrals\n• Create a fresh update schedule\n• Not change user's opt-in status\n\n**Note:** This is typically only needed for troubleshooting or testing.\n\nDo you want to reset the update schedule anyway?\" \
		--button1text \"Reset Schedule\" \
		--button2text \"Cancel\" \
		--icon \"/Users/$targetUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
		--width 550 \
		--height 400 \
		--ontop"
		
		eval "$dialogApp $confirmDialog"
		return $?
	fi
}

show_success_dialog() {
	local user_opted_out_before="$1"
	
	if [[ "$user_opted_out_before" == "true" ]]; then
		successDialog="--title \"Adobe Updates Re-enabled\" \
		--messagefont 'size=14' \
		--message \"**Success!** Adobe automatic updates have been re-enabled for $targetUser.\n\n**What happens next:**\n• User will receive update prompts according to the schedule\n• User has 2 new deferrals available\n• Update schedule has been regenerated\n\n**The user can still:**\n• Defer updates (2 times max)\n• Opt out again if desired\n• Update manually through Creative Cloud Desktop app\n\n*The next update prompt will appear based on the new schedule.*\" \
		--button1text \"OK\" \
		--icon \"/Users/$targetUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
		--width 550 \
		--height 400 \
		--ontop"
	else
		successDialog="--title \"Update Schedule Reset\" \
		--messagefont 'size=14' \
		--message \"**Success!** Adobe update schedule has been reset for $targetUser.\n\n**What was reset:**\n• Deferral count cleared\n• New update schedule generated\n• Time file recreated\n\n**Status:** User remains opted-in for automatic updates.\n\n*This reset is useful for troubleshooting or testing purposes.*\" \
		--button1text \"OK\" \
		--icon \"/Users/$targetUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
		--width 500 \
		--height 350 \
		--ontop"
	fi
	
	eval "$dialogApp $successDialog"
}

show_all_users_warning() {
	warningDialog="--title \"WARNING: Reset All Users\" \
	--messagefont 'size=14' \
	--message \"**⚠️ DANGER ⚠️**\n\n**This will reset Adobe update settings for ALL users on this system!**\n\n**This action will:**\n• Re-enable updates for all users who opted out\n• Clear all deferral counts\n• Remove all existing update schedules\n\n**⚠️ This cannot be undone easily ⚠️**\n\nAre you absolutely sure you want to proceed?\" \
	--button1text \"Yes, Reset All\" \
	--button2text \"Cancel\" \
	--icon \"SF=exclamationmark.triangle.fill,colour=red\" \
	--width 500 \
	--height 400 \
	--ontop"
	
	eval "$dialogApp $warningDialog"
	return $?
}

# Function to check current status
check_status() {
	echo "Checking current Adobe update status..."
	
	# Check opt-out status
	user_opted_out=$(sudo -u "$targetUser" defaults read "$appdomain" user_opted_out 2>/dev/null || echo "false")
	opt_out_date=$(sudo -u "$targetUser" defaults read "$appdomain" opt_out_date 2>/dev/null || echo "not set")
	deferrals=$(sudo -u "$targetUser" defaults read "$appdomain" deferrals 2>/dev/null || echo "not set")
	
	echo "Current Status:"
	echo "  - Opted Out: $user_opted_out"
	echo "  - Opt-out Date: $opt_out_date"
	echo "  - Remaining Deferrals: $deferrals"
	echo "  - Time File Exists: $([ -f "$timeFile" ] && echo "Yes" || echo "No")"
	
	if [[ -f "$timeFile" ]]; then
		epoch_count=$(wc -l < "$timeFile" 2>/dev/null || echo "0")
		echo "  - Scheduled Updates: $epoch_count"
		if [[ $epoch_count -gt 0 ]]; then
			next_epoch=$(head -1 "$timeFile" 2>/dev/null)
			if [[ -n "$next_epoch" && "$next_epoch" != "" ]]; then
				echo "  - Next Update: $(date -r $next_epoch 2>/dev/null || echo 'Invalid date')"
			fi
		fi
	fi
	echo ""
}

# Function to reset user preferences
reset_preferences() {
	echo "Resetting user preferences..."
	
	# Remove opt-out flags
	sudo -u "$targetUser" defaults delete "$appdomain" user_opted_out 2>/dev/null
	sudo -u "$targetUser" defaults delete "$appdomain" opt_out_date 2>/dev/null
	
	# Reset deferrals
	sudo -u "$targetUser" defaults delete "$appdomain" deferrals 2>/dev/null
	
	echo "✓ Removed opt-out flags"
	echo "✓ Reset deferral count"
}

# Function to regenerate epoch times
regenerate_epochs() {
	echo "Regenerating update schedule..."
	
	# Create directory if it doesn't exist
	mkdir -p "/Users/$targetUser/Library/J24/Scripts/RUM/"
	chown "$targetUser" "/Users/$targetUser/Library/J24/Scripts/RUM/"
	
	# Generate new epoch times (every 2 months for next 2 years)
	current_epoch=$(date +%s)
	
	# Remove old time file
	[ -f "$timeFile" ] && rm "$timeFile"
	
	# Generate future epochs starting from current time
	for i in {0..11}; do
		# Add 2 months (approximately 60 days) to current time
		future_epoch=$((current_epoch + (i * 60 * 24 * 60 * 60)))
		echo "$future_epoch" >> "$timeFile"
	done
	
	# Set proper ownership
	chown "$targetUser" "$timeFile"
	
	echo "✓ Created new update schedule"
	echo "✓ Next update will be triggered: $(date -r $current_epoch)"
}

# Function to reset all users (admin option)
reset_all_users() {
	echo "Resetting Adobe updates for all users..."
	
	# Find all user home directories
	for userHome in /Users/*; do
		if [[ -d "$userHome" && ! "$userHome" =~ (Shared|Guest) ]]; then
			userName=$(basename "$userHome")
			if [[ "$userName" != "." && "$userName" != ".." ]]; then
				echo "Resetting for user: $userName"
				
				# Reset preferences for this user
				sudo -u "$userName" defaults delete "$appdomain" user_opted_out 2>/dev/null
				sudo -u "$userName" defaults delete "$appdomain" opt_out_date 2>/dev/null
				sudo -u "$userName" defaults delete "$appdomain" deferrals 2>/dev/null
				
				# Reset time file
				userTimeFile="/Users/$userName/Library/J24/Scripts/RUM/adobeRUM_epoch_times.txt"
				[ -f "$userTimeFile" ] && rm "$userTimeFile"
				
				echo "  ✓ Reset complete for $userName"
			fi
		fi
	done
	
	echo ""
	echo "All users have been reset. Run the main script to regenerate schedules."
}

# Main execution
echo "Adobe RUM Reset Script"
echo "Current time: $(date)"
echo ""

# Ensure swiftDialog is available
ensure_dialog

# Check for special flags
case "$1" in
	"--all")
		show_all_users_warning
		if [[ $? -eq 0 ]]; then
			reset_all_users
			
			# Show completion dialog
			allCompleteDialog="--title \"All Users Reset Complete\" \
			--messagefont 'size=14' \
			--message \"**All users have been reset successfully!**\n\n**What was done:**\n• Removed opt-out flags for all users\n• Cleared all deferral counts\n• Deleted existing update schedules\n\n**Next steps:**\n• Run the main Adobe RUM script to regenerate schedules\n• Users will receive update prompts according to new schedules\n\n*This operation affected all user accounts on this system.*\" \
			--button1text \"OK\" \
			--icon \"SF=checkmark.circle.fill,colour=green\" \
			--width 500 \
			--height 350 \
			--ontop"
			
			eval "$dialogApp $allCompleteDialog"
		else
			echo "Operation cancelled by user."
		fi
		exit 0
	;;
	"--status")
		check_status
		show_status_dialog
		exit 0
	;;
	"--help"|"-h")
		helpDialog="--title \"Adobe RUM Reset Help\" \
		--messagefont 'size=14' \
		--message \"**Adobe RUM Reset Script Help**\n\n**Usage:** $0 [options] [username]\n\n**Options:**\n• **--status** - Check current status only\n• **--all** - Reset ALL users (dangerous!)\n• **--help, -h** - Show this help\n\n**Examples:**\n• **$0** - Reset current console user\n• **$0 jsmith** - Reset specific user 'jsmith'\n• **$0 --status** - Check status without changes\n• **$0 --all** - Reset all users on system\n\n*This script re-enables Adobe automatic updates for users who previously opted out.*\" \
		--button1text \"OK\" \
		--icon \"/Users/$targetUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png\" \
		--width 600 \
		--height 450 \
		--ontop"
		
		eval "$dialogApp $helpDialog"
		exit 0
	;;
esac

# Show current status in dialog
echo "Checking current status..."
check_status

# Store current opt-out status for later
user_opted_out_before=$(sudo -u "$targetUser" defaults read "$appdomain" user_opted_out 2>/dev/null || echo "false")

# Show confirmation dialog and get user choice
show_reset_confirmation
dialog_result=$?

if [[ $dialog_result -eq 0 ]]; then
	# User clicked primary button (Re-enable/Reset)
	echo "User confirmed reset operation"
	reset_preferences
	regenerate_epochs
	show_success_dialog "$user_opted_out_before"
	echo "Reset completed successfully!"
else
	# User clicked Cancel or closed dialog
	cancelDialog="--title \"Operation Cancelled\" \
	--messagefont 'size=14' \
	--message \"**No changes were made.**\n\nThe Adobe update settings for $targetUser remain unchanged.\n\n*You can run this script again anytime to reset the settings.*\" \
	--button1text \"OK\" \
	--icon \"SF=xmark.circle.fill,colour=orange\" \
	--width 400 \
	--height 250 \
	--ontop"
	
	eval "$dialogApp $cancelDialog"
	echo "Operation cancelled by user."
fi