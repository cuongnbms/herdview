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
into `blocked` and `done` produce a bubble.

**Since**:
The moment HerdPet observed an Agent's current Status. Herdr does not report timestamps,
so timers count from observation, not from the real change.

**Mood**:
The single value the pet animates: `blocked`, `working`, `done`, or `idle`, chosen from
all Agents by that priority.
_Avoid_: Aggregate state

**Pet pack**:
A `pet.json` plus spritesheet directory under `~/.agentpet/pets/`, in AgentPet's format,
providing one animation clip per Mood.
