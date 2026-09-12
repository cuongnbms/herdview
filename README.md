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

A bar across the top counts the herd: how many agents are blocked, and quietly
how many are working or done. Below it the window lists every agent, one section
per host: the directory it is working in with its session beside it, then what
the agent calls itself, its status, and how long it has held that status. Where
an agent has no working directory the session leads instead. A row blinks for
as long as its agent is `blocked` (orange) or `done` (blue) — the two statuses
that are asking for a person — so a glance at the window answers whether
anything is waiting on you, and it keeps asking until you come. Every blinking
row pulses in step.
The list scrolls and the host headings stay put as it does. The window remembers
where you put it and how big you made it. `Keep on Top` in the Window menu
(⌘T) makes it float above other apps' windows so the herd stays readable while
you work elsewhere; it is off until you ask for it, and remembered between
launches.

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
