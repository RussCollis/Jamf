#!/bin/sh
################################################
# A script to collect the Version of Homebrew. #
################################################

if [ -x /opt/homebrew/bin/brew ] ; then
    REPOSITORY=/opt/homebrew
else
    REPOSITORY=$(/usr/bin/readlink -f "$(which brew)" | /usr/bin/rev | /usr/bin/cut -d/ -f3- | /usr/bin/rev)
fi

if [ -f "${REPOSITORY}/.git/refs/heads/stable" ] ; then
    read -r REVISION 2>/dev/null <"${REPOSITORY}/.git/refs/heads/stable"
elif [ -f "${REPOSITORY}/.git/HEAD" ] ; then
    read -r REVISION 2>/dev/null <"${REPOSITORY}/.git/HEAD"
fi

RESULT=$(/usr/bin/grep "${REVISION}.*tag" "${REPOSITORY}/.git/FETCH_HEAD" 2>/dev/null | /usr/bin/cut -d\' -f2)

/bin/echo "<result>${RESULT}</result>"

exit 0