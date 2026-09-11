# HerdPet

A macOS app that shows every coding agent running inside
[Herdr](https://herdr.dev), locally and on remote machines over SSH, in one
window, with a menu bar item carrying the number that are blocked.

State comes from Herdr's own detection (`agent.list` on each session's socket),
never from agent hooks. See `docs/adr/` for why.

## Requirements

- macOS 13+, Swift toolchain (Xcode Command Line Tools).
- Herdr installed on every host you want to watch.
- For remote hosts: SSH access with a key that needs no passphrase prompt
  (`ssh-add` it, or use a Keychain-backed key). The app runs `ssh` itself.

## Configure

`~/.config/herdpet/config.toml`:

```toml
[[hosts]]
name = "local"
herdr_path = "/opt/homebrew/bin/herdr"

[[hosts]]
name = "devtuf"
ssh = "devtuf"              # ssh alias or user@host
herdr_path = "/home/cuongnb/.local/bin/herdr"
poll_seconds = 2            # optional, default 2
```

A config from an older version may still carry `pet`, `[clips]` or `[messages]`.
Those keys are ignored — HerdPet has no pet to configure any more — and the file
loads as it always did.

The window lists every agent, one section per host: its name, its session and
short working directory, its status, and how long it has held that status. A row
tints for three seconds when its agent turns `blocked` or `done`. The window
remembers where you put it and how big you made it.

The menu bar item shows how many agents are `blocked`, in orange, and clicking it
shows or hides the window. Closing the window does not quit the app: the herd
keeps being polled, and the menu bar item or the Dock icon brings the window
back.

Every 30 seconds each host is asked `herdr session list --json`; every running
session is polled every `poll_seconds` with `agent.list`. Remote sessions are
reached through `ssh -N -L ~/.herdpet/sock/<host>-<session>.sock:<remote socket> <host>`.

## Build and run

```bash
make          # release .app → build/HerdPet.app
make run      # build and open
make test     # swift test
make clean
```

Or without Make: `swift test && ./scripts/build-app.sh && open build/HerdPet.app`.

Logs go to the unified log: `log stream --predicate 'process == "herdpet"'`.
