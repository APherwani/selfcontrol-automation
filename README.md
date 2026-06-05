# SelfControl Scheduled Start

This repo contains a small macOS `launchd` automation prototype for starting the SelfControl app automatically.

## Recommendation

If you just want scheduled focus blocks on macOS, use [Raycast Focus](https://www.raycast.com/core-features/focus) instead of this repo.

Raycast Focus is free, maintained, and built into Raycast. It can block apps and websites, supports custom categories, works through Raycast deeplinks, and integrates with macOS Focus Filters. It also avoids this repo's hardest problem: trying to drive SelfControl's privileged helper and macOS authorization flow from an unattended shell script.

Useful Raycast docs:

- [Raycast Focus manual](https://manual.raycast.com/focus)
- [Raycast Focus Filters](https://manual.raycast.com/focus/how-to-create-a-focus-filter/)

This repo is best treated as a reference or learning artifact. It is not the recommended path for a reliable daily focus setup.

## Current Status

This project is experimental and may not reliably start unattended blocks on current versions of SelfControl.

The `launchd` schedule can fire at the right time, but SelfControl 4's CLI still goes through macOS Authorization Services before starting a block. In particular, it may try to authorize or reinstall SelfControl's privileged helper, `org.eyebeam.selfcontrold`, and acquire SelfControl's `startBlock` authorization right. Those steps are designed for an interactive user session. When the command is launched automatically by `launchd`, macOS may refuse, delay, or hide that authorization flow.

That means this repo can correctly install a LaunchAgent and still fail to start the actual SelfControl block at 9am. Do not rely on it as your only enforcement mechanism.

The likely durable fix is upstream or app-level work in SelfControl itself: scheduled starts need to be part of SelfControl's own app/helper model, not an outside shell wrapper fighting the authorization layer.

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

Most users should not install this. Use Raycast Focus unless you specifically want to experiment with SelfControl automation and understand the limitation above: installation success means the scheduler was installed, not that unattended SelfControl starts are guaranteed to work.

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

The installer currently prints output like:

```text
Installing /Users/you/Library/Application Support/selfcontrol-automation/start-selfcontrol-block and /Users/you/Library/LaunchAgents/com.selfcontrol-automation.start.plist.
Installed. SelfControl will run weekdays from 09:00 to 17:00.
SelfControl app: /Applications/SelfControl.app
Logs: /Users/you/Library/Logs/selfcontrol-automation.log
```

This output only confirms that the LaunchAgent was installed.

Watch the automation log with:

```zsh
tail -f "$HOME/Library/Logs/selfcontrol-automation.log"
```

## Troubleshooting

If the scheduled job runs but the log says SelfControl failed to authorize or install its helper, the LaunchAgent probably did its part and SelfControl failed during macOS authorization.

Common failing log lines look like:

```text
ERROR: Failed to authorize installing selfcontrold with status -60005.
ERROR: Failed to authorize installing selfcontrold with status -60007.
There was an error authorizing the installation of SelfControl's helper tool.
```

You can try opening SelfControl once and approving its helper installation if prompted. Then rerun the installer:

```zsh
./install-selfcontrol-automation.sh 09:00 17:00 weekdays
```

This may still not be enough for fully unattended scheduled starts. SelfControl's CLI can request authorization again when the scheduled command runs.

To confirm both jobs are loaded:

```zsh
launchctl print system/org.eyebeam.selfcontrold
launchctl print "gui/$(id -u)/com.selfcontrol-automation.start"
```

If the 9am run was missed or failed and you want to start today's block immediately, run:

```zsh
launchctl kickstart -k "gui/$(id -u)/com.selfcontrol-automation.start"
```

That asks `launchd` to run the installed job immediately. It can still hit the same SelfControl authorization problem.

If `launchctl print "gui/$(id -u)/com.selfcontrol-automation.start"` shows the job ran but exited with `70: EX_SOFTWARE`, check the log first. That usually means the runner fired, then SelfControl failed.

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

Unattended scheduled starts are not currently reliable because of SelfControl's macOS authorization/helper flow. This is the main limitation of the project.

Start and end times must be on the same calendar day. Overnight schedules such as `22:00` to `06:00` are not supported as written.

If the runner wakes up after the configured end time has already passed, it exits without starting a block.

## Checks

CI runs `bash -n *.sh` and `shellcheck *.sh`.

## License

MIT
