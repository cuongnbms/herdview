# 0004: Rename the app to Herdview

> Status: Accepted · Date: 2026-09-12 · Amends [0003](0003-main-window-instead-of-a-floating-pet.md)

## Context

ADR 0003 deleted the pet and left the app called HerdPet. Its closing consequence read:

> The app is still called HerdPet and no longer has a pet. The name is kept: renaming the
> app, its bundle id and its config path would cost the user's config location and their
> place in the menu bar for a cosmetic win.

That weighed a real cost against a cosmetic gain, and on those terms it was right. Both
halves have since turned out to be wrong.

The cost was measured. The app is built into `build/` and has never been installed to
`/Applications`; there is no login item, no Dock persistence, and the menu bar slot is
whatever macOS hands out at launch. The config is one 166-byte file with two hosts in it.
The preferences under `com.herdpet.app` amount to a window frame, one `alwaysOnTop` flag,
and six dead keys left by the pet. There is one user.

The gain is not cosmetic. `Pet` names a subsystem ADR 0003 deleted — the sprite player, the
pack loader, the moods, the speech bubble. A reader meeting the name now expects a mascot
on the desktop and finds a window listing agents. The name is the first line of the
documentation and it describes something that does not exist.

## Decision

Rename the app to **Herdview**: `Herdview` as displayed, `herdview` for the binary and
paths, `HerdviewCore` for the module, `com.herdview.app` for the bundle id. `Herd` survives
from the old name and from Herdr, whose herd this is a view of; `view` is what the app
actually is — one window over the whole herd.

Nothing in the app migrates anything. The config moves by hand
(`mv ~/.config/herdpet ~/.config/herdview`) and the README says so. `~/.herdpet/sock` is
discarded: it holds only SSH forward sockets, recreated on the next poll. The preferences
under the old bundle id are abandoned rather than copied across domains — re-dragging the
window and pressing ⌘T once costs less than the code that would carry two keys over, and it
takes the six dead pet keys with it. The keys themselves are renamed too
(`herdview.mainWindow`, `herdview.alwaysOnTop`), so nothing in the new domain reads as if it
came from the old one.

`Herdr` is a separate, third-party project (herdr.dev). The name deliberately does not read
as `Herdr <something>`, which would imply an affiliation that does not exist.

## Consequences

The window position and `Keep on Top` reset once, on the first launch under the new bundle
id. A config left at `~/.config/herdpet/config.toml` is not found and the window shows the
config error naming the new path.

`~/Workspace/utils/herdpet`, the git remote, and the filenames under
`docs/superpowers/specs/` and `docs/superpowers/plans/` keep the old name. They are a record
of what was decided when, and renaming them would falsify it. ADR 0003 is likewise left as
written; this ADR amends it rather than editing it.

`swift test` cannot run on the development machine (no Xcode, so no XCTest), so the rename
was verified by a release build, a standalone `swiftc` binary loading the real config from
the new path, and launching the packaged app.

## Alternatives considered

| Alternative | Why not chosen |
|-------------|----------------|
| Keep `HerdPet`, as ADR 0003 decided | The cost that justified keeping it turned out to be a window position and one toggle. The name still describes a deleted subsystem. |
| Keep the bundle id `com.herdpet.app`, rename only what shows | Preferences survive, but the id contradicts the app's name forever — the exact confusion the rename exists to remove, moved somewhere harder to see. |
| Migrate config and preferences in code on first launch | Migration code for a single user with one 166-byte file, and it would have to stay in the app forever to be worth writing. A `mv` in the README does the same job once. |
