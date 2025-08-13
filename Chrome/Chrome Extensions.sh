#!/bin/bash

# Setting IFS Env to only use new lines as field seperator 
IFS=$'\n'

# Get current user from console device
currentUser=`ls -l /dev/console | awk {' print $3 '}`

# Get last logged in user from loginwindow preferences
lastUser=`defaults read /Library/Preferences/com.apple.loginwindow lastUserName`

# Determine which user's home directory to use
if [[ "$currentUser" = "" || "$currentUser" = "root" ]]
then 
    userHome=`/usr/bin/dscl . -read /Users/$lastUser NFSHomeDirectory | awk -F ": " '{print $2}'`
else 
    userHome=`/usr/bin/dscl . -read /Users/$currentUser NFSHomeDirectory | awk -F ": " '{print $2}'`
fi

# Function to create Chrome extension list
createChromeExtList ()
{
    # Loop through all manifest.json files in Chrome extensions directory
    for manifest in $(find "$userHome/Library/Application Support/Google/Chrome/Default/Extensions" -name 'manifest.json')
    do 
        # Extract extension name from manifest
        name=$(cat $manifest | grep '"name":' | awk -F "\"" '{print $4}')
        
        # Check if name contains localization message key
        if [[ `echo $name | grep "__MSG"` ]]
        then
            # Extract message key
            msgName="\"`echo $name | awk -F '__MSG_|__' '{print $2}'`\":"
            
            # Try to find localized name in en/messages.json
            if [ -f $(dirname $manifest)/_locales/en/messages.json ]
            then 
                reportedName=$(cat $(dirname $manifest)/_locales/en/messages.json | grep -i -A 3 "$msgName" | grep "message" | head -1 | awk -F ": " '{print $2}' | tr -d "\"")
            # Try to find localized name in en_US/messages.json
            elif [ -f $(dirname $manifest)/_locales/en_US/messages.json ]
            then 
                reportedName=$(cat $(dirname $manifest)/_locales/en_US/messages.json | grep -i -A 3 "$msgName" | grep "message" | head -1 | awk -F ": " '{print $2}' | tr -d "\"")
            fi
        else
            # Use name directly from manifest
            reportedName=$(cat $manifest | grep '"name":' | awk -F "\"" '{print $4}')
        fi
        
        # Extract version from manifest
        version=$(cat $manifest | grep '"version":' | awk -F "\"" '{print $4}')
        
        # Get extension ID from directory structure
        extID=$(basename $(dirname $(dirname $manifest)))
        
        # This is the default output style - looks nice in JSS
        # Comment out line below if you wish to use alternate output
        echo -e "Name: $reportedName \nVersion: $version \nID: $extID \n"
        
        # This is the alternate output style - looks ugly in JSS, but possibly more useful
        # Uncomment line below to use this output instead
        #echo -e "$reportedName;$version;$extID"
    done
}

# Check if Chrome extensions directory exists
if [ -d "$userHome/Library/Application Support/Google/Chrome/Default/Extensions" ]
then 
    result="`createChromeExtList`"
else 
    result="NA"
fi

# Output result in XML format
echo "<result>$result</result>"