# HerdPet in a main window, without the pet

Date: 2026-09-11
Status: approved

## Purpose

Show the herd in a normal macOS window, and delete the floating pet.

The floating pet was the reason for most of the app. It carried a sprite player, a
spritesheet slicer, a pet-pack loader, per-mood clips, clip bindings, a size control, an
animation-speed control, a mood resolver, a chatter pool, and a speech bubble — and it
still needed a pet pack installed under `~/.agentpet/pets/` before it could draw anything
but a placeholder pawprint. What it showed, when it worked, was one line per agent in a
bubble that holds five of them.

The list is the value. A window holds it better than a bubble can: it is resizable and
scrollable, every agent fits, it does not sit on top of the desktop, and it needs nothing
installed beyond the app.

## What changes

- The floating `NSPanel` and everything that draws the pet are deleted.
- A standard `NSWindow` shows the agent list, one section per Host.
- The app becomes a regular app: Dock icon, Cmd-Tab, app menu.
- The menu bar item stays; it opens and hides the window instead of showing a popover.
- The popover and its settings page are deleted.
- `pet`, `[clips]` and `[messages]` leave the config. An old config keeps working; the
  keys are ignored.

## App shape

### Activation and main menu

`main.swift` sets `NSApp.setActivationPolicy(.regular)`, and `scripts/AppInfo.plist`
drops `LSUIElement`, which currently forces the app into the agent category and is why it
has no Dock icon. Both are needed: the activation policy alone does not override the
plist reliably.

The app has no main menu today, which a regular app needs for ⌘Q and the app menu. A new
`MainMenu.swift` builds one in code: the app menu (About HerdPet, Hide, Hide Others, Quit
HerdPet ⌘Q) and the Window menu (Minimize, Zoom, Bring All to Front).

### Main window

`MainWindowController` replaces `PetWindowController`. One `NSWindow`, style
`[.titled, .closable, .miniaturizable, .resizable]`, title `HerdPet`, content
`AgentListView` — the agent list that the popover shows today, unchanged in what it draws.

- `contentMinSize` of 360×240 keeps the list readable when the window is small.
- The frame is remembered with a window frame autosave name, replacing the panel's
  hand-rolled `UserDefaults` anchor; the first launch centres the window.
- `isReleasedWhenClosed = false`, and `AppDelegate` returns `false` from
  `applicationShouldTerminateAfterLastWindowClosed`. Closing the window hides it; polling
  continues and the menu bar item stays. `applicationShouldHandleReopen` brings it back
  when the Dock icon is clicked.
- The window is shown at launch.

### Status item

`StatusBarController` keeps the paw and the orange `blocked` count. It loses the
`NSPopover`, its `MenuViewModel`, and its `PetModel` dependency; clicking toggles the
window: hidden (or another app is frontmost) means show and activate, otherwise hide.

### Composition

`AppDelegate` keeps the config load, `AgentStore`, and `Monitor`, and owns
`MainWindowController` and `StatusBarController`. The pet wiring goes:
`store.$agents → PetModel.mood`, `PetModel.update(agents:)`, and the transition-to-pet
flash.

## Window content

The popover's `AgentList` moves to `AgentListView.swift` as-is: a one-second
`TimelineView`, the config error when there is one, "no hosts configured" when there are
none, then one `HostSection` per Host with an `AgentRow` each. Its fixed `width: 360`
becomes a `minWidth`, so the window can be resized wider. `AgentTitles`, `AgentIcons`,
`StatusColor` and `TimerFormatter` are unchanged.

`MenuViewModel`, `SettingsPage`, `PetPickerRow`, `PetSizeRow`, `AnimationSpeedRow`,
`ClipBindingRows` and `Footer` are deleted with the pet. The version moves to the About
panel that the app menu provides.

## Highlight and Transition

A row in the agent list still tints for three seconds when its agent turns `blocked` or
`done`, which is what the pet's bubble did. The state moves from `PetModel` into
`AgentStore`: `highlighted: Set<String>`, a three-second expiry per agent, and the
decision to flash taken where the transitions already are, in `apply(host:session:snapshot:)`.
`AgentStore.onTransition` and the `AppDelegate` wiring around it are deleted; `Transition`
and `AgentSnapshotReducer` are untouched.

This keeps the one signal that says *what just changed* in a view that has no other, and
leaves `Transition` with a consumer instead of dead core code.

## What is deleted

| | Files |
|---|---|
| App | `PetModel`, `PetView`, `PetWindowController`, `PetLayout`, `SpriteLayerView`, `SpriteSlicer`, `PetPackLoader` |
| Core | `Mood` (+ `MoodResolver`), `BubbleLines`, `AnimationSpeed`, `ClipBindings`, `PetSize`, `AgentBubbleRows` |
| Tests | `MoodResolverTests`, `BubbleLinesTests`, `AnimationSpeedTests` |

The uncommitted Animation speed feature is deleted with them: it only ever scaled the
pet's clips, and a list has no clips.

## Config

`HerdPetConfig` becomes the host list and nothing else: `pet`, `clips`, `messages`,
`defaultClips` and `clipIndex` are removed. `[messages]` and `[clips]` are ordinary TOML
tables the loader simply stops reading, so a config written for the pet still loads and
its hosts still appear — the removed keys are ignored silently rather than reported, since
the README says they are gone.

## Domain language

`CONTEXT.md` loses the pet: `Roster`, `Chatter`, `Pool`, `Mood`, `Pet size`, `Animation
speed`, `Pet pack`, `Clip`, `Clip binding`. `Host`, `Session`, `Agent`, `Status`,
`Transition`, `Highlight` and `Since` stay; `Highlight` is reworded for an agent row in
the window rather than a roster row in a bubble, and the file's opening line stops
promising a floating pet.

The repository and the app keep the name HerdPet although it no longer has a pet;
renaming the app, bundle id and config path is a separate change.

Source: [ADR 0003](../../adr/0003-main-window-instead-of-a-floating-pet.md)

## Verification

The user has declined new automated tests for this change, so the table below is the whole
of it. Worth knowing first: on the machine this was written on there is no Xcode and the
Command Line Tools SDK ships no `XCTest`, so the test target can neither be run nor even
compiled — `swift test` and `swift build --build-tests` both fail on `unable to resolve
module dependency: 'XCTest'`. Only the app target is verifiable here, which is a
pre-existing condition of this environment and not something this change introduces.

| Check | How |
|---|---|
| The app compiles | `swift build` |
| Window opens at launch, list renders, resize and close work | `make run` |
| Closing the window leaves the app alive and polling | close it; the menu bar item stays |
| Clicking the paw shows and hides the window | click it twice |
| Dock icon, Cmd-Tab, ⌘Q | Dock and keyboard |
| An old config with `pet`, `[clips]`, `[messages]` still lists its hosts | run with such a config in place |
| A blocked/done transition tints its row for three seconds | watch a live agent change status |

`ConfigLoaderTests` is edited so it keeps matching the sources: its pet assertions go with
the fields they test. The edits to that file **cannot be compiled or run on this machine**
(see above), so they are verified by reading alone. The claim that an old config still
loads is therefore **not** covered by a test either; it is verified by hand, per the table.

## Out of scope

- An app icon. With a Dock icon the app shows the generic one; an `.icns` is a separate
  change.
- Renaming the app, its bundle id, or `~/.config/herdpet/config.toml`.
- Click-to-focus an agent's pane, notifications, and a login item.
- Removing `~/.agentpet/pets` or any user data.

## Risks

- Deleting seven App files and six Core files is mostly subtraction, but the app's entry
  and window wiring is rewritten, and there is no automated coverage of the App target,
  so verification rests on the manual table.
- `.regular` changes how the app behaves when it is not the frontmost app; the status item
  and polling must keep working with the window closed.
- Users of the pet lose it, and the Animation speed work with it. That is the point of the
  change, and ADR 0003 records it.
