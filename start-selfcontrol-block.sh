#!/bin/bash
set -euo pipefail

default_control_uid() {
  if [[ -n "${SUDO_UID:-}" && "${SUDO_UID}" != "0" ]]; then
    /bin/echo "${SUDO_UID}"
  else
    /usr/bin/id -u
  fi
}

SELFCONTROL_APP="${SELFCONTROL_APP:-/Applications/SelfControl.app}"
SELFCONTROL_CLI="${SELFCONTROL_CLI:-${SELFCONTROL_APP}/Contents/MacOS/selfcontrol-cli}"
CONTROL_UID="${CONTROL_UID:-$(default_control_uid)}"
END_TIME=""
DRY_RUN=0
TIME_RE='^([01]?[0-9]|2[0-3]):[0-5][0-9]$'

log() {
  /bin/echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S %z')] $*"
}

usage() {
  /bin/cat <<'EOF'
Usage:
  start-selfcontrol-block [--dry-run] [--until HH:MM]

Without --until, SelfControl's saved duration is used.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --until)
      if [[ $# -lt 2 ]]; then
        usage
        exit 64
      fi
      END_TIME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ -n "${END_TIME}" && ! ${END_TIME} =~ ${TIME_RE} ]]; then
  log "ERROR: --until must be HH:MM in 24-hour time, like 17:00."
  exit 64
fi

if (( ! DRY_RUN )); then
  if [[ ! -x "${SELFCONTROL_CLI}" ]]; then
    log "ERROR: SelfControl CLI not found at ${SELFCONTROL_CLI}"
    exit 1
  fi

  if "${SELFCONTROL_CLI}" is-running 2>&1 | /usr/bin/tail -1 | /usr/bin/grep -q "YES"; then
    log "SelfControl block is already running; leaving it alone."
    exit 0
  fi
fi

if [[ -z "${END_TIME}" ]]; then
  if (( DRY_RUN )); then
    log "Dry run: would start SelfControl for uid ${CONTROL_UID} using saved SelfControl duration."
    exit 0
  fi

  log "Starting SelfControl block for uid ${CONTROL_UID} using saved SelfControl duration."
  "${SELFCONTROL_CLI}" --uid "${CONTROL_UID}" start
  log "SelfControl start command finished."
  exit 0
fi

if [[ -z "${CONTROL_HOME:-}" ]]; then
  CONTROL_USER="${CONTROL_USER:-$(/usr/bin/id -un "${CONTROL_UID}")}"
  CONTROL_HOME="$(/usr/bin/dscl . -read "/Users/${CONTROL_USER}" NFSHomeDirectory | /usr/bin/awk '{print $2}')"
fi

PREFS_PLIST="${CONTROL_HOME}/Library/Preferences/org.eyebeam.SelfControl.plist"
if [[ ! -r "${PREFS_PLIST}" ]]; then
  log "ERROR: SelfControl preferences not readable at ${PREFS_PLIST}"
  exit 1
fi

TODAY="$(/bin/date '+%Y-%m-%d')"
END_EPOCH="$(/bin/date -j -f "%Y-%m-%d %H:%M:%S" "${TODAY} ${END_TIME}:00" '+%s')"
NOW_EPOCH="$(/bin/date '+%s')"

if (( END_EPOCH <= NOW_EPOCH )); then
  log "Configured end time ${END_TIME} has already passed today; not starting a block."
  exit 0
fi

ENDDATE_UTC="$(/bin/date -r "${END_EPOCH}" -u '+%Y-%m-%dT%H:%M:%SZ')"
BLOCKLIST_COUNT="$(/usr/bin/plutil -extract Blocklist raw -expect array -o - "${PREFS_PLIST}")"

if (( BLOCKLIST_COUNT < 1 )); then
  log "ERROR: SelfControl saved blocklist is empty."
  exit 1
fi

TMP_BLOCKLIST="$(/usr/bin/mktemp "/tmp/selfcontrol-blocklist.XXXXXX.selfcontrol")"
trap '/bin/rm -f "${TMP_BLOCKLIST}"' EXIT

BLOCKLIST_XML="$(/usr/bin/plutil -extract Blocklist xml1 -expect array -o - "${PREFS_PLIST}")"
BLOCK_AS_WHITELIST="NO"
if BLOCK_AS_WHITELIST_RAW="$(/usr/bin/plutil -extract BlockAsWhitelist raw -expect bool -o - "${PREFS_PLIST}" 2>/dev/null)"; then
  if [[ "${BLOCK_AS_WHITELIST_RAW}" == "true" ]]; then
    BLOCK_AS_WHITELIST="YES"
  fi
fi

/usr/bin/plutil -create xml1 "${TMP_BLOCKLIST}"
/usr/bin/plutil -insert HostBlacklist -xml "${BLOCKLIST_XML}" "${TMP_BLOCKLIST}"
/usr/bin/plutil -insert BlockAsWhitelist -bool "${BLOCK_AS_WHITELIST}" "${TMP_BLOCKLIST}"
/usr/bin/plutil -convert binary1 "${TMP_BLOCKLIST}"

if (( DRY_RUN )); then
  log "Dry run: would start SelfControl for uid ${CONTROL_UID}; block would end at ${END_TIME} local (${ENDDATE_UTC})."
  /usr/bin/plutil -p "${TMP_BLOCKLIST}"
  exit 0
fi

log "Starting SelfControl block for uid ${CONTROL_UID}; block ends at ${END_TIME} local (${ENDDATE_UTC})."
"${SELFCONTROL_CLI}" --uid "${CONTROL_UID}" start --blocklist "${TMP_BLOCKLIST}" --enddate "${ENDDATE_UTC}"
log "SelfControl start command finished."
