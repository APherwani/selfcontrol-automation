#!/bin/bash
set -euo pipefail

LABEL="${LABEL:-com.selfcontrol-automation.start}"
CONTROL_UID="${CONTROL_UID:-$(/usr/bin/id -u)}"
CONTROL_HOME="${CONTROL_HOME:-${HOME}}"
LAUNCH_DOMAIN="gui/${CONTROL_UID}"
INSTALL_DIR="${INSTALL_DIR:-${CONTROL_HOME}/Library/Application Support/selfcontrol-automation}"
PLIST_DEST="${PLIST_DEST:-${CONTROL_HOME}/Library/LaunchAgents/${LABEL}.plist}"
SCRIPT_DEST="${SCRIPT_DEST:-${INSTALL_DIR}/start-selfcontrol-block}"
LEGACY_SCRIPT_DEST="${LEGACY_SCRIPT_DEST:-/usr/local/bin/start-selfcontrol-block}"
LEGACY_PLIST_DEST="${LEGACY_PLIST_DEST:-/Library/LaunchDaemons/${LABEL}.plist}"

remove_jobs_for_runner() {
  local plist label program

  for plist in "${CONTROL_HOME}/Library/LaunchAgents/"*.plist; do
    [[ -e "${plist}" ]] || continue

    label="$(/usr/bin/plutil -extract Label raw -o - "${plist}" 2>/dev/null || true)"
    program="$(/usr/bin/plutil -extract ProgramArguments.0 raw -o - "${plist}" 2>/dev/null || true)"

    if [[ -n "${label}" && "${program}" == "${SCRIPT_DEST}" ]]; then
      /bin/echo "Removing SelfControl automation job ${label}."
      /bin/launchctl bootout "${LAUNCH_DOMAIN}" "${plist}" 2>/dev/null || true
      /bin/rm -f "${plist}"
    fi
  done
}

/bin/echo "Removing scheduled automation ${LABEL}."
/bin/launchctl bootout "${LAUNCH_DOMAIN}" "${PLIST_DEST}" 2>/dev/null || true
/bin/rm -f "${PLIST_DEST}" "${SCRIPT_DEST}"
remove_jobs_for_runner

if [[ -f "${LEGACY_PLIST_DEST}" ]]; then
  /bin/echo "Removing old root LaunchDaemon ${LEGACY_PLIST_DEST}; macOS may ask for your password."
  /usr/bin/sudo /bin/launchctl bootout system "${LEGACY_PLIST_DEST}" 2>/dev/null || true
  /usr/bin/sudo /bin/rm -f "${LEGACY_PLIST_DEST}"
fi

if [[ -f "${LEGACY_SCRIPT_DEST}" ]]; then
  /bin/echo "Removing old root runner ${LEGACY_SCRIPT_DEST}; macOS may ask for your password."
  /usr/bin/sudo /bin/rm -f "${LEGACY_SCRIPT_DEST}"
fi

/bin/echo "Removed SelfControl automation. Any active SelfControl block is untouched."
