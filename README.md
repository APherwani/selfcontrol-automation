# SelfControl Scheduled Start

This workspace contains a small macOS `launchd` automation for starting the SelfControl app automatically.

SelfControl's own command-line helper is used. The installer looks for `SelfControl.app` in `/Applications`, `~/Applications`, and `~/Downloads`.

If your app lives somewhere else, pass `SELFCONTROL_APP` when installing.

The scheduled block uses the blocklist already saved in the SelfControl app, while the automation decides the end time.

The installer records the current user's UID and home directory in the LaunchDaemon so SelfControl reads the right preferences when the scheduled job runs as root.

## Safety Warning

Read the scripts before running; this writes to `/Library/LaunchDaemons` and `/usr/local/bin`. The installer uses `sudo` to create root-owned files in those locations.

This project is intentionally small so the privileged behavior is easy to audit. The uninstall script removes the scheduled automation and installed runner, but it does not stop, shorten, or undo any SelfControl block that is already running.

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
/Library/LaunchDaemons/com.selfcontrol-automation.start.plist
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

For a non-standard app location:

```zsh
SELFCONTROL_APP="$HOME/Apps/SelfControl.app" ./install-selfcontrol-automation.sh 09:00 17:00 weekdays
```

## Terminal Demo

Installing a weekday 9-to-5 schedule looks like this:

```zsh
./install-selfcontrol-automation.sh 09:00 17:00 weekdays
```

Expected output:

```text
Installing /usr/local/bin/start-selfcontrol-block and /Library/LaunchDaemons/com.selfcontrol-automation.start.plist; macOS may ask for your password.
Installed. SelfControl will run weekdays from 09:00 to 17:00.
SelfControl app: /Applications/SelfControl.app
Logs: /var/log/selfcontrol-automation.log
```

Watch the automation log with:

```zsh
tail -f /var/log/selfcontrol-automation.log
```

## Remove

```zsh
./uninstall-selfcontrol-automation.sh
```

This only removes the scheduled automation and installed runner script. It does not stop, shorten, or undo any SelfControl block that is already running. This is on purpose.

## Logs

```zsh
tail -f /var/log/selfcontrol-automation.log
```

## Dry Run

To verify the generated blocklist and end time without starting a block:

```zsh
./start-selfcontrol-block.sh --dry-run --until 17:00
```

## Limitations

Start and end times must be on the same calendar day. Overnight schedules such as `22:00` to `06:00` are not supported as written.

If the runner wakes up after the configured end time has already passed, it exits without starting a block.

## Checks

CI runs `bash -n *.sh` and `shellcheck *.sh`.

## License

MIT
