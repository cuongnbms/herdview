# 0003: Show the herd in a main window, accepting the loss of the floating pet

> Status: Accepted · Date: 2026-09-11

## Context

HerdPet exists to show what every agent is doing. The floating pet was the way it did
that, and the pet was the reason for most of the code: a sprite player, a spritesheet
slicer, a pack loader, per-mood clips, clip bindings, a size control, an animation-speed
control, a mood resolver, a chatter pool, and a speech bubble. Its key was still only ever
readable after a pet pack was installed under `~/.agentpet/pets/`.

What the bubble showed, when it worked, was one line per agent — five at most, the rest
counted as "+N more" — floating over the desktop at a spot the user picked by dragging it
there.

Source: [design spec](../superpowers/specs/2026-09-11-herdpet-window-design.md)

## Decision

Delete the pet and the popover. Show the agent list in a standard `NSWindow`, make the app
a regular Dock app, and keep the menu bar item as the way to open and hide that window and
as the blocked count.

The list is the value and a window holds it better than a bubble can: it resizes and
scrolls, every agent fits instead of five, it stays off the desktop, and it needs nothing
installed beyond the app. The menu bar item keeps the one thing the pet was genuinely good
at — being visible when the window is not.

## Consequences

The app becomes a regular app: Dock icon, Cmd-Tab, app menu, and no `LSUIElement`. Closing
the window hides it rather than quitting; the herd keeps being polled while it is closed.

`~/.agentpet/pets` and the config's `pet`, `[clips]` and `[messages]` become meaningless.
They are ignored rather than rejected, so an existing config keeps working, and the README
has to say they are gone.

The app is still called HerdPet and no longer has a pet. The name is kept: renaming the
app, its bundle id and its config path would cost the user's config location and their
place in the menu bar for a cosmetic win.

`Highlight` survives in a new place — a row in the window tints for three seconds when its
agent turns `blocked` or `done` — so `Transition` still has a consumer. `Mood`, `Roster`,
`Chatter` and `Pool` do not survive.

## Alternatives considered

| Alternative | Why not chosen |
|-------------|----------------|
| Keep the floating pet, fix its layout and readability | It would still cap the list at five rows, still need a pet pack installed, and still sit on top of the desktop; the whole sprite and pack subsystem stays. |
| Keep only the menu bar popover, make it taller | A popover closes as soon as focus moves and is not resizable or scrollable; it cannot be the place you leave open on a second display. |
| Add the window and keep the pet and the popover too | Three views of one list, two of them worse, and the pet subsystem would be maintained for its own sake. |
