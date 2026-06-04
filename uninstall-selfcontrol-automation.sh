#!/bin/bash
set -euo pipefail

LABEL="${LABEL:-com.selfcontrol-automation.start}"
PLIST_DEST="/Library/LaunchDaemons/${LABEL}.plist"
SCRIPT_DEST="${SCRIPT_DEST:-/usr/local/bin/start-selfcontrol-block}"

remove_jobs_for_runner() {
  local plist label program

  for plist in /Library/LaunchDaemons/*.plist; do
    [[ -e "${plist}" ]] || continue

    label="$(/usr/bin/plutil -extract Label raw -o - "${plist}" 2>/dev/null || true)"
    program="$(/usr/bin/plutil -extract ProgramArguments.0 raw -o - "${plist}" 2>/dev/null || true)"

    if [[ -n "${label}" && "${program}" == "${SCRIPT_DEST}" ]]; then
      /bin/echo "Removing SelfControl automation job ${label}."
      /usr/bin/sudo /bin/launchctl bootout system "${plist}" 2>/dev/null || true
      /usr/bin/sudo /bin/rm -f "${plist}"
    fi
  done
}

/bin/echo "Removing scheduled automation ${LABEL}; macOS may ask for your password."
/usr/bin/sudo /bin/launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
/usr/bin/sudo /bin/rm -f "${PLIST_DEST}" "${SCRIPT_DEST}"
remove_jobs_for_runner
/bin/echo "Removed SelfControl automation. Any active SelfControl block is untouched."
