#!/bin/bash
set -euo pipefail

default_control_uid() {
  if [[ -n "${SUDO_UID:-}" && "${SUDO_UID}" != "0" ]]; then
    /bin/echo "${SUDO_UID}"
  else
    /usr/bin/id -u
  fi
}

home_for_uid() {
  local user
  user="$(/usr/bin/id -un "$1")"
  /usr/bin/dscl . -read "/Users/${user}" NFSHomeDirectory | /usr/bin/awk '{print $2}'
}

CONTROL_UID="${CONTROL_UID:-$(default_control_uid)}"
CONTROL_HOME="${CONTROL_HOME:-$(home_for_uid "${CONTROL_UID}" 2>/dev/null || /bin/echo "${HOME}")}"
LABEL="${LABEL:-com.selfcontrol-automation.start}"
SCRIPT_SOURCE="$(cd "$(dirname "$0")" && pwd)/start-selfcontrol-block.sh"
INSTALL_DIR="${INSTALL_DIR:-${CONTROL_HOME}/Library/Application Support/selfcontrol-automation}"
SCRIPT_DEST="${SCRIPT_DEST:-${INSTALL_DIR}/start-selfcontrol-block}"
PLIST_DEST="${PLIST_DEST:-${CONTROL_HOME}/Library/LaunchAgents/${LABEL}.plist}"
LOG_PATH="${LOG_PATH:-${CONTROL_HOME}/Library/Logs/selfcontrol-automation.log}"
LAUNCH_DOMAIN="gui/${CONTROL_UID}"
SELFCONTROL_HELPER_LABEL="${SELFCONTROL_HELPER_LABEL:-org.eyebeam.selfcontrold}"
SELFCONTROL_HELPER_PLIST="${SELFCONTROL_HELPER_PLIST:-/Library/LaunchDaemons/${SELFCONTROL_HELPER_LABEL}.plist}"
LEGACY_SCRIPT_DEST="${LEGACY_SCRIPT_DEST:-/usr/local/bin/start-selfcontrol-block}"
LEGACY_PLIST_DEST="${LEGACY_PLIST_DEST:-/Library/LaunchDaemons/${LABEL}.plist}"

usage() {
  /bin/cat <<'EOF'
Usage:
  ./install-selfcontrol-automation.sh START_HH:MM END_HH:MM [daily|weekdays|weekends]

Examples:
  ./install-selfcontrol-automation.sh 09:00 17:00 weekdays
  ./install-selfcontrol-automation.sh 22:30 23:59 daily

The scheduled block uses your existing SelfControl app blocklist and ends at END_HH:MM.
EOF
}

xml_escape() {
  /usr/bin/sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&apos;/g" <<< "$1"
}

detect_selfcontrol_app() {
  local candidates=(
    "${SELFCONTROL_APP:-}"
    "/Applications/SelfControl.app"
    "${CONTROL_HOME}/Applications/SelfControl.app"
    "${CONTROL_HOME}/Downloads/SelfControl.app"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "${candidate}" && -x "${candidate}/Contents/MacOS/selfcontrol-cli" ]]; then
      /bin/echo "${candidate}"
      return 0
    fi
  done

  return 1
}

remove_other_user_jobs_for_runner() {
  local plist label program

  for plist in "${CONTROL_HOME}/Library/LaunchAgents/"*.plist; do
    [[ -e "${plist}" ]] || continue

    label="$(/usr/bin/plutil -extract Label raw -o - "${plist}" 2>/dev/null || true)"
    program="$(/usr/bin/plutil -extract ProgramArguments.0 raw -o - "${plist}" 2>/dev/null || true)"

    if [[ -n "${label}" && "${label}" != "${LABEL}" && "${program}" == "${SCRIPT_DEST}" ]]; then
      /bin/echo "Removing old SelfControl automation job ${label}."
      /bin/launchctl bootout "${LAUNCH_DOMAIN}" "${plist}" 2>/dev/null || true
      /bin/rm -f "${plist}"
    fi
  done
}

remove_legacy_system_job() {
  if [[ -f "${LEGACY_PLIST_DEST}" ]]; then
    /bin/echo "Removing old root LaunchDaemon ${LEGACY_PLIST_DEST}; macOS may ask for your password."
    /usr/bin/sudo /bin/launchctl bootout system "${LEGACY_PLIST_DEST}" 2>/dev/null || true
    /usr/bin/sudo /bin/rm -f "${LEGACY_PLIST_DEST}"
  fi

  if [[ -f "${LEGACY_SCRIPT_DEST}" && "${LEGACY_SCRIPT_DEST}" != "${SCRIPT_DEST}" ]]; then
    /bin/echo "Removing old root runner ${LEGACY_SCRIPT_DEST}; macOS may ask for your password."
    /usr/bin/sudo /bin/rm -f "${LEGACY_SCRIPT_DEST}"
  fi
}

warn_if_selfcontrol_helper_not_loaded() {
  if [[ ! -f "${SELFCONTROL_HELPER_PLIST}" ]]; then
    /bin/echo "WARNING: SelfControl helper plist was not found at ${SELFCONTROL_HELPER_PLIST}." >&2
    /bin/echo "Open SelfControl once and approve its helper installation if prompted." >&2
    return 0
  fi

  if /bin/launchctl print "system/${SELFCONTROL_HELPER_LABEL}" >/dev/null 2>&1; then
    return 0
  fi

  /bin/echo "WARNING: SelfControl privileged helper is not currently loaded." >&2
  /bin/echo "The first scheduled start may show a macOS authorization prompt unless SelfControl has already installed its helper." >&2
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 64
fi

START_TIME="$1"
END_TIME="$2"
CADENCE="${3:-daily}"
TIME_RE='^([01]?[0-9]|2[0-3]):[0-5][0-9]$'

if [[ ! ${START_TIME} =~ ${TIME_RE} ]]; then
  /bin/echo "ERROR: Start time must be HH:MM in 24-hour time, like 09:00." >&2
  exit 64
fi

if [[ ! ${END_TIME} =~ ${TIME_RE} ]]; then
  /bin/echo "ERROR: End time must be HH:MM in 24-hour time, like 17:00." >&2
  exit 64
fi

HOUR="${START_TIME%%:*}"
MINUTE="${START_TIME##*:}"
HOUR="$((10#${HOUR}))"
MINUTE="$((10#${MINUTE}))"

if ! SELFCONTROL_APP="$(detect_selfcontrol_app)"; then
  /bin/echo "ERROR: Could not find SelfControl.app." >&2
  /bin/echo "Set SELFCONTROL_APP=/path/to/SelfControl.app and run the installer again." >&2
  exit 1
fi

SCRIPT_DEST_XML="$(xml_escape "${SCRIPT_DEST}")"
END_TIME_XML="$(xml_escape "${END_TIME}")"
CONTROL_UID_XML="$(xml_escape "${CONTROL_UID}")"
CONTROL_HOME_XML="$(xml_escape "${CONTROL_HOME}")"
SELFCONTROL_APP_XML="$(xml_escape "${SELFCONTROL_APP}")"
LOG_PATH_XML="$(xml_escape "${LOG_PATH}")"
LABEL_XML="$(xml_escape "${LABEL}")"

case "${CADENCE}" in
  daily)
    CALENDAR_XML="
    <dict>
      <key>Hour</key><integer>${HOUR}</integer>
      <key>Minute</key><integer>${MINUTE}</integer>
    </dict>"
    ;;
  weekdays)
    CALENDAR_XML=""
    for weekday in 1 2 3 4 5; do
      CALENDAR_XML="${CALENDAR_XML}
    <dict>
      <key>Weekday</key><integer>${weekday}</integer>
      <key>Hour</key><integer>${HOUR}</integer>
      <key>Minute</key><integer>${MINUTE}</integer>
    </dict>"
    done
    ;;
  weekends)
    CALENDAR_XML=""
    for weekday in 0 6; do
      CALENDAR_XML="${CALENDAR_XML}
    <dict>
      <key>Weekday</key><integer>${weekday}</integer>
      <key>Hour</key><integer>${HOUR}</integer>
      <key>Minute</key><integer>${MINUTE}</integer>
    </dict>"
    done
    ;;
  *)
    /bin/echo "ERROR: Cadence must be daily, weekdays, or weekends." >&2
    exit 64
    ;;
esac

TMP_PLIST="$(/usr/bin/mktemp "/tmp/${LABEL}.XXXXXX.plist")"
trap '/bin/rm -f "${TMP_PLIST}"' EXIT

/bin/cat > "${TMP_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL_XML}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${SCRIPT_DEST_XML}</string>
    <string>--until</string>
    <string>${END_TIME_XML}</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>CONTROL_UID</key>
    <string>${CONTROL_UID_XML}</string>
    <key>CONTROL_HOME</key>
    <string>${CONTROL_HOME_XML}</string>
    <key>SELFCONTROL_APP</key>
    <string>${SELFCONTROL_APP_XML}</string>
  </dict>

  <key>StartCalendarInterval</key>
  <array>${CALENDAR_XML}
  </array>

  <key>StandardOutPath</key>
  <string>${LOG_PATH_XML}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_PATH_XML}</string>
</dict>
</plist>
EOF

/usr/bin/plutil -lint "${TMP_PLIST}" >/dev/null

/bin/echo "Installing ${SCRIPT_DEST} and ${PLIST_DEST}."
/bin/mkdir -p "$(/usr/bin/dirname "${SCRIPT_DEST}")" "$(/usr/bin/dirname "${PLIST_DEST}")" "$(/usr/bin/dirname "${LOG_PATH}")"
/usr/bin/install -m 0755 "${SCRIPT_SOURCE}" "${SCRIPT_DEST}"
/usr/bin/install -m 0644 "${TMP_PLIST}" "${PLIST_DEST}"
warn_if_selfcontrol_helper_not_loaded
remove_other_user_jobs_for_runner
remove_legacy_system_job
/bin/launchctl bootout "${LAUNCH_DOMAIN}" "${PLIST_DEST}" 2>/dev/null || true
/bin/launchctl bootstrap "${LAUNCH_DOMAIN}" "${PLIST_DEST}"
/bin/launchctl enable "${LAUNCH_DOMAIN}/${LABEL}"

/bin/echo "Installed. SelfControl will run ${CADENCE} from ${START_TIME} to ${END_TIME}."
/bin/echo "SelfControl app: ${SELFCONTROL_APP}"
/bin/echo "Logs: ${LOG_PATH}"
