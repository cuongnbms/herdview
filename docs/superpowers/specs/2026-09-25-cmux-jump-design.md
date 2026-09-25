# Jump from an Agent to its pane in cmux

Date: 2026-09-25
Status: draft

## Purpose

The window says which Agent is asking for a person; it does not take the person there.
Herdr runs inside cmux, one cmux tab per attached Session, so answering a `blocked` Agent
today means finding the right cmux workspace, the right tab, and then the right pane in
Herdr by hand.

Clicking an Agent — its row, or the Notification about it — does all three: it brings cmux
to the front on the Terminal Tab attached to that Agent's Session, with Herdr focused on the
Agent's pane.

## What changes

- A row in the agent list is clickable. It highlights under the pointer and shows a
  pointing-hand cursor; the comment in `AgentListView` and the README line that say
  clicking a row does nothing are rewritten.
- Clicking a Notification Jumps to its Agent instead of only showing the window. If the
  Agent is no longer tracked, it shows the window as it does today.
- Nothing is added to the config.

## How a Jump resolves

A Jump runs for one Agent: its Host, Session and pane id.

1. **Read the world.** Run `ps -axo tty=,args=` and
   `cmux --json tree --all`. Both run on this Mac; the Terminal Tab of a remote Host is
   still a local process.
2. **Find Terminal Tabs.** A process is a Herdr client attached to a Session when its
   arguments are one of:

   | Arguments | Remote | Session |
   |---|---|---|
   | `herdr` | — | `default` |
   | `herdr --session X` | — | `X` |
   | `herdr session attach X` | — | `X` |
   | `herdr --remote R` | `R` | `default` |
   | `herdr --remote R --session X` | `R` | `X` |

   `herdr` is matched on the executable's basename, so `/opt/homebrew/bin/herdr` counts.
   Herdr's own helper processes — `herdr client`, `herdr server`, anything with
   `remote-client-bridge` — are not clients. Any other subcommand (`herdr agent list`,
   `herdr pane …`) is not a client either.

   A client belongs to a Host when its Remote equals that Host's `ssh` value, or when it
   has no Remote and the Host is local. Its tty (`ttys004` from `ps`) is matched to the
   cmux terminal surface whose `tty` is the same; a client on a tty that no cmux surface
   holds is ignored (it lives in another terminal app).
3. **Plan.** In order:
   - **Focus.** If one or more Terminal Tabs hold the Agent's Session, pick the one inside
     a Matching Workspace first, otherwise the first in cmux's tree order, and focus it.
   - **New tab.** Otherwise, if a cmux workspace is a Matching Workspace, open a new
     terminal tab in it running the attach command.
   - **New workspace.** Otherwise, create a cmux workspace named after the Session running
     the attach command. Next time, that workspace is a Matching Workspace.

   A **Matching Workspace** is a cmux workspace whose title, lowercased with each run of
   whitespace replaced by `-`, equals the Session name ("Blue Matrix" and "blue-matrix"
   both match `blue-matrix`). When several match, a title equal to the Session name
   verbatim wins, then the first in tree order.

   The **attach command** is `herdr --session <X>` for a local Host and
   `herdr --remote <ssh> --session <X>` for a remote one, using the local Host's
   `herdr_path` when one is configured and `herdr` otherwise (a remote attach still runs
   the local binary).
4. **Focus the Agent in Herdr.** Run `herdr --session <X> agent focus <pane id>` against
   the Agent's Host — directly for local, through `ssh` for remote, the way
   `HostCommand.sessionList` does. This runs *before* the cmux step: focus is state on
   the Herdr server, so a tab opened a moment later attaches straight onto the Agent's
   pane.
5. **Act in cmux.** Focus: `cmux rpc surface.focus '{"surface_id":"<ref>"}'`, which also
   selects the surface's workspace. New tab: `cmux new-surface --workspace <ref>
   --command <attach> --focus true`. New workspace: `cmux new-workspace --name <session>
   --command <attach> --focus true`.
6. **Bring cmux forward.** Activate the app with bundle id `com.cmuxterm.app`.

The world is read on every Jump, never cached: tabs, ttys and workspaces change all the
time, and a Jump is rare enough that two short processes do not matter.

## Failure

A Jump that cannot finish — cmux not installed, its socket refusing, `ssh` failing, the
pane gone — logs one `NSLog` line saying which step failed and beeps (`NSBeep()`). No
dialog. A failed Herdr focus does not stop the cmux step: landing on the right tab with the
wrong pane is still most of the way there.

Jumps run one at a time. A second click while one is running waits for it, then reads the
world afresh, so a double click on a Session with no Terminal Tab opens one tab and then
focuses it, not two.

## Components

`HerdviewCore` (pure, unit tested):

- **`HerdrAttachment`** — parses one `ps` line (`tty`, `args`) into
  `(tty, remote: String?, session: String)` or `nil`, per the table above.
- **`CmuxTree`** — decodes `cmux --json tree --all` into workspaces in tree order, each with
  `ref`, `title`, and its terminal surfaces (`ref`, `tty`).
- **`JumpPlanner`** — `plan(host:session:attachments:tree:herdrPath:) -> JumpPlan`, where
  `JumpPlan` is `.focus(surface:)`, `.newTab(workspace:command:)` or
  `.newWorkspace(name:command:)`. Owns Matching Workspace and every rule in step 3.
- **`HostCommand.agentFocus(for:session:paneId:)`** — the step 4 command.
- **`CmuxCommand`** — builds the `cmux` invocations for step 5 and the tree read, with the
  executable fixed at `/Applications/cmux.app/Contents/Resources/bin/cmux`.

`Sources/App`:

- **`Jumper`** — runs a Jump with `ProcessRunner`: reads the world, plans, focuses in Herdr,
  acts in cmux, activates cmux. One at a time.
- **`AgentListView`** — tap, hover highlight and cursor on a row, calling `onJump(agent)`.
- **`TransitionNotifier`** — a Notification's request identifier is already the Agent's
  key; on a click it looks that key up in `AgentStore` and Jumps.

## Testing

- XCTest files for `HerdrAttachment` (every row of the table, helper processes, other
  subcommands, full executable paths), `CmuxTree` (a fixture captured from a real
  `cmux --json tree --all`), `JumpPlanner` (focus, several tabs, Matching Workspace with a
  verbatim tie-break, new tab, new workspace, a remote client not matching a local Host)
  and `HostCommand.agentFocus` (local and remote).
- This Mac has no XCTest; they run through the `swiftc` shim, as the other core tests do.
- Clicking in the built app is checked by hand: a row whose Session has a tab, one whose
  Session has none but a Matching Workspace, one with neither, and a Notification click.

## Out of scope

- Terminals other than cmux. A Session attached only in another terminal app is treated as
  having no Terminal Tab.
- A config key for the cmux path or for a fallback workspace.
- Focusing a Herdr client that is attached through something other than the commands in
  the table.
