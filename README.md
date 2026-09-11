# HerdPet

A macOS menu bar app that shows every coding agent running inside
[Herdr](https://herdr.dev), locally and on remote machines over SSH, with one
floating pixel pet that reacts to the aggregate state.

State comes from Herdr's own detection (`agent.list` on each session's socket),
never from agent hooks. See `docs/adr/` for why.

## Requirements

- macOS 13+, Swift toolchain (Xcode Command Line Tools).
- Herdr installed on every host you want to watch.
- For remote hosts: SSH access with a key that needs no passphrase prompt
  (`ssh-add` it, or use a Keychain-backed key). The app runs `ssh` itself.
- One or more pet packs under `~/.agentpet/pets/<id>/` (AgentPet format).
  Without one, a pawprint placeholder is shown.

## Configure

`~/.config/herdpet/config.toml`:

```toml
pet = "boba"                # ~/.agentpet/pets/boba, optional default

[clips]                     # spritesheet row per mood, optional
idle = 0
working = 1
blocked = 2
done = 3

[messages]                  # bubble lines per mood, optional
blocked = ["I need you!", "Your turn 👀"]
done = ["All done! ✅", "Ta-da!"]

[[hosts]]
name = "local"
herdr_path = "/opt/homebrew/bin/herdr"

[[hosts]]
name = "devtuf"
ssh = "devtuf"              # ssh alias or user@host
herdr_path = "/home/cuongnb/.local/bin/herdr"
poll_seconds = 2            # optional, default 2
```

The pet can also be picked from the menu bar popover; that choice is remembered
and wins over `pet` in the config.

The pet talks the way AgentPet's does: an idle line that changes every couple
of minutes, a compact `…` while any agent is working, and a line for `blocked`
or `done`. When an agent turns `blocked` or `done` an alert bubble names it
(`name @ host`) for eight seconds. Each mood draws from a built-in English pool;
a non-empty list under `[messages]` replaces that mood's pool.

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
