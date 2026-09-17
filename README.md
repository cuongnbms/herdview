# Herdview

A macOS app that shows every coding agent running inside
[Herdr](https://herdr.dev), locally and on remote machines over SSH, in one
window, with a menu bar item to call that window up.

State comes from Herdr's own detection (`agent.list` on each session's socket),
never from agent hooks. See `docs/adr/` for why.

## Requirements

- macOS 13+, Swift toolchain (Xcode Command Line Tools).
- Herdr installed on every host you want to watch.
- For remote hosts: SSH access with a key that needs no passphrase prompt
  (`ssh-add` it, or use a Keychain-backed key). The app runs `ssh` itself.

## Configure

`~/.config/herdview/config.toml`:

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

The app was called HerdPet and read `~/.config/herdpet/config.toml`. Nothing
migrates that file for you: move it yourself with
`mv ~/.config/herdpet ~/.config/herdview`. A config from back then may still
carry `pet`, `[clips]` or `[messages]`; those keys are ignored — there has been
no pet since `docs/adr/0003` — and the file loads as it always did. The window
position and `Keep on Top` do not survive the rename either, since they were
stored under the old bundle id.

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

When an agent turns `blocked` or `done`, macOS also posts a notification: the
same directory, session and title the row shows, and clicking it brings the
window up. You are asked for permission the first time the app runs. One agent
only ever holds one notification — going `blocked`, then `done`, replaces it
rather than leaving a stack behind — and no banner is shown while Herdview is the
app in front, since the blinking row is already saying it. There is no switch for
this in the app; the switch is System Settings › Notifications › Herdview.

Above the hosts, a Quota card shows how much of each plan is used: Claude, Codex,
OpenCode Go and Grok, one row each. Every Window — `5h`, `week`, `month`, or a
per-model week like `week · Fable` — shows the percent used and how long until it
resets, and its bar turns orange from 90%. The numbers come from each CLI's own
sign-in on this Mac, never from the remote hosts, since every host spends the
same accounts:

| Provider | Credential read |
|---|---|
| Claude | Keychain item `Claude Code-credentials` |
| Codex | `~/.codex/auth.json` |
| OpenCode Go | `opencode-go` key in `~/.local/share/opencode/auth.json` |
| Grok | `~/.grok/auth.json` |

They are only read. Herdview never refreshes a token and never runs a CLI (see
[ADR 0005](docs/adr/0005-quota-from-provider-apis-without-refresh.md)), so a
CLI you have not used for a few hours may show
"sign-in expired — run grok" with its last numbers dimmed; running that CLI
once brings it back. A CLI that is not signed in shows "not signed in". Quota
is fetched every 5 minutes, and when the window is shown, but only while the
window is visible. The first read of Claude's Keychain item may ask for
permission; choose Always Allow. None of these usage endpoints is documented,
so a row that says "unreadable response" means a Provider changed its API.

The menu bar item shows how many agents are `blocked`, in orange, and clicking it
shows or hides the window. Closing the window does not quit the app: the herd
keeps being polled, and the menu bar item or the Dock icon brings the window
back.

Every 30 seconds each host is asked `herdr session list --json`; every running
session is polled every `poll_seconds` with `agent.list`. Remote sessions are
reached through `ssh -N -L ~/.herdview/sock/<host>-<session>.sock:<remote socket> <host>`.

## Build and run

```bash
make          # release .app → build/Herdview.app
make run      # build and open
make test     # swift test
make clean
```

Or without Make: `swift test && ./scripts/build-app.sh && open build/Herdview.app`.

Logs go to the unified log: `log stream --predicate 'process == "herdview"'`.
