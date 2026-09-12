# Herdview

A macOS app that mirrors the live state of coding agents running inside Herdr, on the
local machine and on remote machines, in one window listing them all, with a menu bar item
carrying the count of the ones that need attention.

## Language

**Host**:
A machine that runs Herdr: the local Mac, or a remote machine reached over SSH.
_Avoid_: Server, box, source

**Session**:
One Herdr server on a Host, with its own socket. A Host has a default Session and any
number of named Sessions; only a running Session is watched.
_Avoid_: Workspace, instance

**Agent**:
The coding agent process Herdr has detected in one pane of a Session. Identified by Host,
Session, and pane id; it disappears when Herdr stops listing it.
_Avoid_: Pane, terminal, process

**Status**:
Herdr's classification of an Agent, taken verbatim: `idle`, `working`, `blocked`, `done`,
or `unknown`. Herdview never derives Status itself.
_Avoid_: State, waiting, registered

**Transition**:
An Agent changing from one Status to another as observed by Herdview. Only transitions
into `blocked` and `done` produce a Highlight.

**Highlight**:
The tint an Agent's row carries for three seconds after its Transition into `blocked` or
`done`. It is the only thing marking a change; the row itself never goes away to announce
one.
_Avoid_: Notification, toast

**Since**:
The moment Herdview observed an Agent's current Status. Herdr does not report timestamps,
so timers count from observation, not from the real change.
