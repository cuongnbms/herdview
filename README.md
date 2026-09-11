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

[clips]                     # fallback spritesheet row per mood, optional
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

The pet pack, how big the pet is drawn (60–240pt, with S/M/L presets), and the
spritesheet clip each state animates are all set from the menu bar popover.
Those choices are remembered per pack and win over `pet` and `[clips]` in the
config, which are only the defaults.

The pet's bubble always lists the agents that are doing something: one row per
`blocked`, `working` or `done` agent as `name @ host`, blocked first, five rows
at most with the rest counted as `+N more`. A row tints for three seconds when
its agent turns `blocked` or `done`. Only when nothing is running does the pet
fall back to an idle line, re-picked every couple of minutes from a built-in
English pool; a non-empty list under `[messages]` replaces that pool.

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
