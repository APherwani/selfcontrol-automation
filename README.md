# SelfControl Scheduled Start

This repo contains a small macOS `launchd` automation for starting the SelfControl app automatically.

SelfControl's own command-line helper is used. The installer looks for `SelfControl.app` in `/Applications`, `~/Applications`, and `~/Downloads`.

If your app lives somewhere else, pass `SELFCONTROL_APP` when installing.

The scheduled block uses the blocklist already saved in the SelfControl app, while the automation decides the end time.

The installer records the current user's UID and home directory in a LaunchAgent so SelfControl reads the right preferences when the scheduled job runs in your login session.

## Safety Warning

Read the scripts before running.

The current installer writes user-owned files to:

```text
~/Library/LaunchAgents/com.selfcontrol-automation.start.plist
~/Library/Application Support/selfcontrol-automation/start-selfcontrol-block
~/Library/Logs/selfcontrol-automation.log
```

It does not install a root-owned scheduler. SelfControl itself uses its own privileged helper, `org.eyebeam.selfcontrold`, to apply blocks. macOS may ask for an administrator password the first time SelfControl installs or authorizes that helper.

If you are upgrading from an older version of this repo, the installer may ask for `sudo` only to remove the previous root LaunchDaemon from `/Library/LaunchDaemons` and the old runner from `/usr/local/bin`.

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

The installer creates a user LaunchAgent in:

```text
~/Library/LaunchAgents/com.selfcontrol-automation.start.plist
```

It also installs the runner script at:

```text
~/Library/Application Support/selfcontrol-automation/start-selfcontrol-block
```

## Upgrade From Old Root Daemon

Older versions installed a root LaunchDaemon. The current version uses a user LaunchAgent because SelfControl's CLI needs to run in your login session after its helper has been authorized.

Run the installer again to migrate:

```zsh
./install-selfcontrol-automation.sh 09:00 17:00 weekdays
```

If macOS asks for a password during migration, it is removing these old root-owned files:

```text
/Library/LaunchDaemons/com.selfcontrol-automation.start.plist
/usr/local/bin/start-selfcontrol-block
```

Removing those files does not stop, shorten, or undo an active SelfControl block.

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
Installing /Users/you/Library/Application Support/selfcontrol-automation/start-selfcontrol-block and /Users/you/Library/LaunchAgents/com.selfcontrol-automation.start.plist.
Installed. SelfControl will run weekdays from 09:00 to 17:00.
SelfControl app: /Applications/SelfControl.app
Logs: /Users/you/Library/Logs/selfcontrol-automation.log
```

Watch the automation log with:

```zsh
tail -f "$HOME/Library/Logs/selfcontrol-automation.log"
```

## Troubleshooting

If the scheduled job runs but the log says SelfControl failed to authorize or install its helper, open SelfControl once and approve its helper installation if prompted. Then rerun the installer:

```zsh
./install-selfcontrol-automation.sh 09:00 17:00 weekdays
```

To confirm both jobs are loaded:

```zsh
launchctl print system/org.eyebeam.selfcontrold
launchctl print "gui/$(id -u)/com.selfcontrol-automation.start"
```

If the 9am run was missed or failed and you want to start today's block immediately, run:

```zsh
launchctl kickstart -k "gui/$(id -u)/com.selfcontrol-automation.start"
```

That starts a real SelfControl block using the installed schedule's end time.

## Remove

```zsh
./uninstall-selfcontrol-automation.sh
```

This only removes the scheduled automation and installed runner script. It does not stop, shorten, or undo any SelfControl block that is already running. This is on purpose.

## Logs

```zsh
tail -f "$HOME/Library/Logs/selfcontrol-automation.log"
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
