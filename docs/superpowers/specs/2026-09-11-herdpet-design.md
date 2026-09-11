# HerdPet design

Date: 2026-09-11
Status: approved

## Purpose

A small macOS menu bar app that shows the live state of every coding agent running inside
Herdr, on the local machine and on remote machines reached over SSH, with one floating pixel
pet that reacts to the aggregate state. Nothing else: no XP, no usage tracking, no hooks, no
remote daemon, no web sync.

HerdPet replaces AgentPet's hook-based state detection with Herdr's own detection. For
Claude Code and most agents Herdr classifies state from the terminal screen (see
[ADR 0001](../../adr/0001-herdr-as-sole-state-source.md)), which covers transitions hooks
miss: permission approval results, Esc interrupts, and questions asked in any language.

## Scope

In v1:

- Menu bar icon with the number of `blocked` agents, orange when that number is non-zero.
- Menu list grouped by host: agent icon, name or pane id, session, short cwd, status, timer.
- One floating pet whose animation follows the aggregate mood.
- Bubble above the pet: mood chatter from per-mood pools (AgentPet's lines, overridable
  under `[messages]`), plus an alert on transitions into `blocked` and `done`.
- Pet pack picked from the popover; the config's `pet` is the default.
- Hosts and sessions discovered from `herdr session list --json`.
- Remote hosts reached by forwarding the Herdr Unix socket over SSH.
- Config from a TOML file. No settings window; the popover holds the pet picker.

Not in v1: click-to-focus, sounds, login item, XP, usage, hooks, remote daemon, web sync,
pet roaming, per-project pets.

## Vocabulary

See [CONTEXT.md](../../../CONTEXT.md). The status vocabulary is Herdr's, unchanged:
`idle`, `working`, `blocked`, `done`, `unknown`.

## Architecture

Swift package, macOS 13+, two targets plus tests:

- `HerdPetCore`: pure logic, no AppKit. Everything here is unit tested.
- `herdpet`: the menu bar app (AppKit + SwiftUI), LSUIElement.
- `HerdPetCoreTests`: XCTest.

Data flow:

```
config.toml
   └─ HostRunner (one per host)
        └─ every 30s: herdr session list --json   (local exec, or ssh <host> <herdr_path> ...)
             └─ SessionWatcher (one per running session)
                  ├─ remote only: SSHForward   ssh -N -L <local.sock>:<remote socket_path> <host>
                  └─ every 2s: agent.list over the Unix socket
                       └─ AgentSnapshotReducer
                            └─ AgentStore (@MainActor)
                                 ├─ StatusBarController + MenuContentView
                                 ├─ PetWindowController (MoodResolver)
                                 └─ BubbleController (transitions)
```

### HerdPetCore

**HerdrProtocol.** Encodes a request as one line of JSON `{"id","method","params"}` and
decodes `{"id","result"}` or `{"id","error":{"code","message"}}`. Unknown fields are ignored.

`AgentInfo` fields used: `pane_id`, `workspace_id`, `tab_id`, `agent`, `display_agent`,
`name`, `cwd`, `agent_status`, `revision`. All except `pane_id`, `workspace_id`,
`agent_status`, `revision` are optional.

**HerdrSocketClient.** Opens the Unix socket, writes one request line, reads one response
line, closes. No long-lived connection. `ECONNREFUSED` and `ENOENT` map to
`.serverNotRunning`; other errors map to `.transport(String)`.

**SessionDiscovery.** Parses `herdr session list --json` into
`[HerdrSession(name, socketPath, running)]`. `socketPath` is absolute as Herdr prints it;
it is never expanded or rewritten.

**HostConfig and ConfigLoader.** Reads `~/.config/herdpet/config.toml`:

```toml
pet = "boba"            # pack id under ~/.agentpet/pets/, optional

[[hosts]]
name = "local"
herdr_path = "/opt/homebrew/bin/herdr"

[[hosts]]
name = "devtuf"
ssh = "devtuf"                          # ssh alias or user@host
herdr_path = "/home/cuongnb/.local/bin/herdr"
poll_seconds = 2                        # optional, default 2
```

A host without `ssh` is local. `herdr_path` is required because a remote non-login shell
may not have `herdr` on PATH. `poll_seconds` defaults to 2.

**AgentSnapshotReducer.** Input: the previous `[TrackedAgent]` for one (host, session) and
the new `[AgentInfo]`. Output: the new `[TrackedAgent]` and `[Transition]`.

- `TrackedAgent(key, host, session, info, status, since)` where
  `key = "\(host)/\(session)/\(pane_id)"`.
- A new key is added with `since = now`; no transition is emitted for it.
- Same key, changed `agent_status`: `since = now`, emit `Transition(key, from, to)`.
- Same key, same status: `since` unchanged, `info` refreshed.
- Same key with `revision` lower than the stored one: ignored.
- Keys missing from the new list are removed; no transition.

`since` is the moment HerdPet observed the change. Herdr does not report timestamps, so
timers restart after a reconnect.

**MoodResolver.** `[TrackedAgent]` to `Mood`: `blocked` if any agent is blocked, else
`working` if any is working, else `done` if any is done, else `idle`. `unknown` counts as
idle.

### herdpet app

**HostRunner.** One actor per host. Every 30 seconds runs discovery: local hosts execute
`herdr_path session list --json` directly; remote hosts run
`/usr/bin/ssh <ssh> <herdr_path> session list --json`. It diffs the set of sessions with
`running == true` against its watchers, starts a `SessionWatcher` for each new one and stops
watchers whose session is no longer running.

**SessionWatcher.** One per running session. For a remote host it owns an `SSHForward`.
Every `poll_seconds` it sends `agent.list` to its local socket path and hands the result to
`AgentStore` tagged with host and session name.

**SSHForward.** Spawns
`/usr/bin/ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o BatchMode=yes -L <local.sock>:<remote socket_path> <ssh>`.
The local socket lives under `~/.herdpet/sock/<host>-<session>.sock` (a short path, because macOS caps Unix socket paths at 104 bytes)
and is unlinked before every spawn. On exit it respawns with backoff 2, 4, 8 up to 60 seconds.

**AgentStore.** `@MainActor ObservableObject`. Merges snapshots from all watchers, keeps the
full `[TrackedAgent]` plus per-host reachability, and forwards transitions to
`BubbleController`. Replacing a session's snapshot with an empty list removes its agents.

**UI.**

- `StatusBarController`: template icon; when any agent is blocked the icon is tinted orange
  and shows the count.
- `MenuContentView`: sections per host in config order. A host that failed discovery shows a
  single "unreachable" row. Each agent row: agent icon (copied from AgentPet's `AgentIcons`),
  `name` or `pane_id`, session name, last path component of `cwd`, status dot, timer since
  `since`. Rows are sorted blocked first, then working, done, idle, unknown.
- `PetWindowController`: borderless floating window at a fixed corner, draggable. Renders
  `PetSpriteView` (AgentPet's `SpriteSlicer` and CALayer sprite view, copied) with the clip
  bound to the current mood. Clips are spritesheet rows; the default binding is
  `idle = 0`, `working = 1`, `blocked = 2`, `done = 3`, overridable per mood in config under
  `[clips]`. A pack with fewer rows falls back to its last row. No roaming.
- `BubbleController`: on a transition into `blocked` or `done`, shows a bubble above the pet
  with the agent's display name and host for 8 seconds, or until the next transition.

## Error handling

- **Server not running** (`.serverNotRunning`): the watcher publishes an empty snapshot, so
  that session's agents disappear, and keeps polling. The next discovery cycle stops the
  watcher when `running` turns false.
- **SSH forward exits**: the local socket file is unlinked, the process respawns with
  backoff, and the session's agents are removed while it is down.
- **Discovery fails** (ssh cannot connect, non-zero exit, unparsable output): the host is
  marked unreachable in the menu, existing watchers keep running, retry next cycle.
- **Herdr error response**: logged, the poll cycle is skipped, existing agents are kept so
  the list does not flicker.
- **Bad config**: the app starts with no hosts; the menu shows the config path and the parse
  error.
- **Missing pet pack**: the pet shows a pawprint placeholder.

## Testing

`swift test` on `HerdPetCoreTests`:

- HerdrProtocol: request encoding, `AgentInfo` decoding with extra fields, error envelope.
- SessionDiscovery: the real `session list --json` output captured from devtuf on
  2026-09-11, including non-running sessions.
- AgentSnapshotReducer: new agent, status change resets `since` and emits a transition,
  unchanged status keeps `since`, removed agent, stale revision ignored.
- MoodResolver: priority order, empty list is idle, unknown counts as idle.
- ConfigLoader: sample file, optional fields absent, local host without `ssh`.
- SSHForward argv construction from a `HostConfig` and socket paths. No live connections.

Live behavior (forward, discovery over ssh, pet rendering) is verified by running the app.

## Reused from AgentPet

Copied, not depended on: `SpriteSlicer.swift`, the CALayer sprite view from
`ImageSpriteView.swift`, `AgentIcons.swift`. Pet packs are read from `~/.agentpet/pets/`
in the existing `pet.json` + spritesheet format.
