# HerdPet

A macOS menu bar app that mirrors the live state of coding agents running inside Herdr, on
the local machine and on remote machines, with one floating pet reacting to the whole.

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
or `unknown`. HerdPet never derives Status itself.
_Avoid_: State, waiting, registered

**Transition**:
An Agent changing from one Status to another as observed by HerdPet. Only transitions
into `blocked` and `done` produce a Highlight.

**Roster**:
The pet's bubble as a list: one row per Agent that is `blocked`, `working` or `done`,
most attention-worthy first, capped at five rows with the rest counted as "+N more".
Shown whenever any such Agent exists, which is most of the time.
_Avoid_: Alert, notification, toast

**Chatter**:
The line the pet shows when the Roster is empty, drawn from the idle Mood's Pool and
re-picked every couple of minutes.
_Avoid_: Chat, message

**Highlight**:
The tint a Roster row carries for three seconds after its Agent's Transition into
`blocked` or `done`. It is the only thing marking a change; the Roster itself never
goes away to announce one.
_Avoid_: Notification, toast

**Pool**:
The lines a Mood can say. Built in, or replaced per Mood by a non-empty list under
`[messages]` in the config. Only the idle Pool reaches the screen now that the Roster
speaks for every other Mood; the rest are still parsed so old configs keep working.

**Since**:
The moment HerdPet observed an Agent's current Status. Herdr does not report timestamps,
so timers count from observation, not from the real change.

**Mood**:
The single value the pet animates: `blocked`, `working`, `done`, or `idle`, chosen from
all Agents by that priority.
_Avoid_: Aggregate state

**Pet size**:
The sprite's edge length in points, 60 to 240, set by slider or S/M/L preset in the
menu bar popover and remembered across launches. The pet's panel is sized from it and
from the Roster's row count, and resizes around the pet's feet.

**Pet pack**:
A `pet.json` plus spritesheet directory under `~/.agentpet/pets/`, in AgentPet's format,
sliced into one Clip per spritesheet row. The one shown is picked in the menu bar
popover; the config's `pet` is only the default.

**Clip**:
One animation of a Pet pack: the frames of a single spritesheet row.

**Clip binding**:
Which Clip a Mood animates, chosen per Pet pack in the menu bar popover and remembered
there. `[clips]` in the config is the fallback for unbound Moods; a binding past the end
of the pack is clamped, never an error.
