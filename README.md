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
- A pet pack under `~/.agentpet/pets/<id>/` (AgentPet format). Without one, a
  pawprint placeholder is shown.

## Configure

`~/.config/herdpet/config.toml`:

```toml
pet = "boba"                # ~/.agentpet/pets/boba, optional

[clips]                     # spritesheet row per mood, optional
idle = 0
working = 1
blocked = 2
done = 3

[[hosts]]
name = "local"
herdr_path = "/opt/homebrew/bin/herdr"

[[hosts]]
name = "devtuf"
ssh = "devtuf"              # ssh alias or user@host
herdr_path = "/home/cuongnb/.local/bin/herdr"
poll_seconds = 2            # optional, default 2
```

Every 30 seconds each host is asked `herdr session list --json`; every running
session is polled every `poll_seconds` with `agent.list`. Remote sessions are
reached through `ssh -N -L ~/.herdpet/sock/<host>-<session>.sock:<remote socket> <host>`.

## Build and run

```bash
swift test
./scripts/build-app.sh
open build/HerdPet.app
```

Logs go to the unified log: `log stream --predicate 'process == "herdpet"'`.
