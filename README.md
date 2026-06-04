# SelfControl Scheduled Start

This workspace contains a small macOS `launchd` automation for starting the SelfControl app automatically.

SelfControl's own command-line helper is used:

```zsh
/Users/arjun/Applications/SelfControl.app/Contents/MacOS/selfcontrol-cli
```

The scheduled block uses the blocklist and duration already saved in the SelfControl app. On this Mac, those settings currently show a 300-minute block and this blocklist:

```text
chess.com
lichess.com
youtube.com
instagram.com
x.com
```

## Install

Choose a 24-hour start time and cadence:

```zsh
./install-selfcontrol-automation.sh 09:00 weekdays
```

Supported cadences:

```text
daily
weekdays
weekends
```

Because SelfControl needs administrator privileges to start blocks reliably without a password prompt later, the installer creates a root LaunchDaemon in:

```text
/Library/LaunchDaemons/com.arjun.selfcontrol.start.plist
```

It also installs the runner script at:

```text
/usr/local/bin/start-selfcontrol-block
```

## Change The Schedule

Run the installer again with a new time or cadence:

```zsh
./install-selfcontrol-automation.sh 22:30 daily
```

## Remove

```zsh
./uninstall-selfcontrol-automation.sh
```

## Logs

```zsh
tail -f /var/log/selfcontrol-automation.log
```
