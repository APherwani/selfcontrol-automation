#!/bin/zsh
set -euo pipefail

SELFCONTROL_APP="${SELFCONTROL_APP:-/Users/arjun/Applications/SelfControl.app}"
SELFCONTROL_CLI="${SELFCONTROL_APP}/Contents/MacOS/selfcontrol-cli"
CONTROL_UID="${CONTROL_UID:-501}"

log() {
  /bin/echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S %z')] $*"
}

if [[ ! -x "${SELFCONTROL_CLI}" ]]; then
  log "ERROR: SelfControl CLI not found at ${SELFCONTROL_CLI}"
  exit 1
fi

if "${SELFCONTROL_CLI}" is-running 2>&1 | /usr/bin/tail -1 | /usr/bin/grep -q "YES"; then
  log "SelfControl block is already running; leaving it alone."
  exit 0
fi

log "Starting SelfControl block for uid ${CONTROL_UID} using saved SelfControl settings."
"${SELFCONTROL_CLI}" --uid "${CONTROL_UID}" start
log "SelfControl start command finished."
