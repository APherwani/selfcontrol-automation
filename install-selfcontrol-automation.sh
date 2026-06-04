#!/bin/zsh
set -euo pipefail

LABEL="com.arjun.selfcontrol.start"
SCRIPT_SOURCE="$(cd "$(dirname "$0")" && pwd)/start-selfcontrol-block.sh"
SCRIPT_DEST="/usr/local/bin/start-selfcontrol-block"
PLIST_DEST="/Library/LaunchDaemons/${LABEL}.plist"

usage() {
  /bin/cat <<'EOF'
Usage:
  ./install-selfcontrol-automation.sh HH:MM [daily|weekdays|weekends]

Examples:
  ./install-selfcontrol-automation.sh 09:00 weekdays
  ./install-selfcontrol-automation.sh 22:30 daily

The scheduled block uses your existing SelfControl app blocklist and duration.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 64
fi

TIME_ARG="$1"
CADENCE="${2:-daily}"

if [[ ! "${TIME_ARG}" =~ '^([01]?[0-9]|2[0-3]):[0-5][0-9]$' ]]; then
  /bin/echo "ERROR: Time must be HH:MM in 24-hour time, like 09:00 or 22:30." >&2
  exit 64
fi

HOUR="${TIME_ARG%%:*}"
MINUTE="${TIME_ARG##*:}"
HOUR="$((10#${HOUR}))"
MINUTE="$((10#${MINUTE}))"

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
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${SCRIPT_DEST}</string>
  </array>

  <key>StartCalendarInterval</key>
  <array>${CALENDAR_XML}
  </array>

  <key>StandardOutPath</key>
  <string>/var/log/selfcontrol-automation.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/selfcontrol-automation.log</string>
</dict>
</plist>
EOF

/usr/bin/plutil -lint "${TMP_PLIST}" >/dev/null

/bin/echo "Installing ${SCRIPT_DEST} and ${PLIST_DEST}; macOS may ask for your password."
/usr/bin/sudo /bin/mkdir -p "$(/usr/bin/dirname "${SCRIPT_DEST}")"
/usr/bin/sudo /usr/bin/install -m 0755 -o root -g wheel "${SCRIPT_SOURCE}" "${SCRIPT_DEST}"
/usr/bin/sudo /usr/bin/install -m 0644 -o root -g wheel "${TMP_PLIST}" "${PLIST_DEST}"
/usr/bin/sudo /bin/launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
/usr/bin/sudo /bin/launchctl bootstrap system "${PLIST_DEST}"
/usr/bin/sudo /bin/launchctl enable "system/${LABEL}"

/bin/echo "Installed. SelfControl will start ${CADENCE} at ${TIME_ARG}."
/bin/echo "Logs: /var/log/selfcontrol-automation.log"
