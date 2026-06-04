#!/bin/zsh
set -euo pipefail

LABEL="com.arjun.selfcontrol.start"
PLIST_DEST="/Library/LaunchDaemons/${LABEL}.plist"
SCRIPT_DEST="/usr/local/bin/start-selfcontrol-block"

/bin/echo "Removing scheduled automation ${LABEL}; macOS may ask for your password."
/usr/bin/sudo /bin/launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
/usr/bin/sudo /bin/rm -f "${PLIST_DEST}" "${SCRIPT_DEST}"
/bin/echo "Removed SelfControl automation. Any active SelfControl block is untouched."
