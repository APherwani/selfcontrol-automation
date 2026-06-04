# SelfControl Scheduled Start

This workspace contains a small macOS `launchd` automation for starting the SelfControl app automatically.

SelfControl's own command-line helper is used:

```zsh
/Users/arjun/Applications/SelfControl.app/Contents/MacOS/selfcontrol-cli
```

The scheduled block uses the blocklist already saved in the SelfControl app, while the automation decides the end time. On this Mac, the saved SelfControl blocklist is currently:

```text
chess.com
lichess.com
youtube.com
instagram.com
x.com
```

## Install

Choose 24-hour start/end times and a cadence:

```zsh
./install-selfcontrol-automation.sh 09:00 17:00 weekdays
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
./install-selfcontrol-automation.sh 10:00 16:00 weekdays
```

## Remove

```zsh
./uninstall-selfcontrol-automation.sh
```

This only removes the scheduled automation and installed runner script. It does not stop, shorten, or undo any SelfControl block that is already running.

## Logs

```zsh
tail -f /var/log/selfcontrol-automation.log
```

## Dry Run

To verify the generated blocklist and end time without starting a block:

```zsh
./start-selfcontrol-block.sh --dry-run --until 17:00
```
