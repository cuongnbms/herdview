# HerdPet Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the floating pet and the menu bar popover with a standard window that lists every agent, keeping the menu bar item as the way to open that window.

**Architecture:** The app becomes a regular Dock app (`NSApp.setActivationPolicy(.regular)`, no `LSUIElement`) with an app menu built in code. A new `MainWindowController` owns one `NSWindow` whose content is the agent list lifted out of the popover into `AgentListView`. The status item loses its popover and instead shows or hides that window. Then the pet is subtracted: seven App files, six Core files and three test files, along with `pet` / `[clips]` / `[messages]` in the config.

**Tech Stack:** Swift 5.10, SwiftPM, macOS 13+, AppKit + SwiftUI. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-11-herdpet-window-design.md`

## Global Constraints

- macOS 13.0 deployment target (see `Package.swift`); do not use API that needs 13.3 or later.
- No new dependencies; the package stays three targets: `HerdPetCore`, `herdpet`, `HerdPetCoreTests`.
- **Verification is `swift build` only.** This machine has no Xcode and the Command Line Tools SDK has no `XCTest`, so `swift test` and `swift build --build-tests` both fail with `unable to resolve module dependency: 'XCTest'`. Edits to test files in this plan cannot be compiled or run anywhere on this machine.
- **No new automated tests.** The user declined them for this change; see the spec's Verification section.
- App name, bundle id (`com.herdpet.app`) and config path (`~/.config/herdpet/config.toml`) do not change.
- Do not touch or delete anything under `~/.agentpet/pets` or the user's config file.
- Follow the existing code style: `@MainActor final class` for App-layer controllers and `ObservableObject` stores, doc comments that explain *why* rather than *what*, and English for code and comments.
- Commit once per task, with a conventional-commit subject line.

---

### Task 1: Make the app a regular app with a main menu

Right now the app is an agent (`LSUIElement`), so it has no Dock icon and no app menu, and ⌘Q does nothing. A window is only meaningful once it is a normal app.

**Files:**
- Create: `Sources/App/MainMenu.swift`
- Modify: `Sources/App/main.swift`
- Modify: `Sources/App/AppDelegate.swift`
- Modify: `scripts/AppInfo.plist`

**Interfaces:**
- Consumes: nothing.
- Produces: `MainMenu.install()`, called from `AppDelegate.applicationWillFinishLaunching(_:)`.

- [ ] **Step 1: Write the main menu**

Create `Sources/App/MainMenu.swift`:

```swift
import AppKit

/// The menu a normal app has to have. HerdPet had none while it was a menu bar
/// agent: it had no window to close and nothing to quit from, so the pet's
/// popover carried a Quit button instead. With a real window the app menu is
/// where ⌘Q lives, and nothing appears at all without one.
@MainActor
enum MainMenu {
    static func install(appName: String = "HerdPet") {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About \(appName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others",
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom",
                           action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front",
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
}
```

Every item is added with `target` left nil on purpose: the actions travel the responder chain to `NSApp` or the key window, which is how a hand-built menu is supposed to work.

- [ ] **Step 2: Drop the agent activation policy in `main.swift`**

Replace the whole file with:

```swift
import AppKit

let delegate = MainActor.assumeIsolated { AppDelegate() }
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
```

- [ ] **Step 3: Install the menu in `AppDelegate`**

Add this method after `applicationDidFinishLaunching`:

```swift
    func applicationWillFinishLaunching(_ notification: Notification) {
        MainMenu.install()
    }
```

- [ ] **Step 4: Drop `LSUIElement` from the bundle**

In `scripts/AppInfo.plist`, delete these two lines:

```xml
	<key>LSUIElement</key>
	<true/>
```

Both this and the activation policy have to go: the plist alone would keep the app out of the Dock however the policy is set at launch.

- [ ] **Step 5: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Run it and look**

Run: `make run`
Expected: a Dock icon appears, the menu bar shows the HerdPet app menu, ⌘Q quits. The pet is still there — it is removed in Task 5.

- [ ] **Step 7: Commit**

```bash
git add Sources/App/MainMenu.swift Sources/App/main.swift Sources/App/AppDelegate.swift scripts/AppInfo.plist
git commit -m "feat(app): make HerdPet a regular app with a main menu"
```

---

### Task 2: Add the main window showing the agent list

The list is the value; this task gives it a window. It also lifts the list out of `MenuContentView` so it stops depending on the pet, which is what lets the popover be deleted next.

**Files:**
- Create: `Sources/App/AgentListView.swift`
- Create: `Sources/App/MainWindowController.swift`
- Modify: `Sources/App/MenuContentView.swift`
- Modify: `Sources/App/AppDelegate.swift`

**Interfaces:**
- Consumes: `AgentStore` (unchanged), `AgentTitles`, `AgentIcons`, `StatusColor`, `TimerFormatter`, `AgentKind` (all unchanged).
- Produces:
  - `AgentListView(store: AgentStore)` — a SwiftUI `View`, internal.
  - `MainWindowController(store: AgentStore)`, with `var isVisible: Bool { get }`, `func show()`, `func hide()`, `func toggle()`.

- [ ] **Step 1: Create `AgentListView.swift`**

This is the popover's list, moved verbatim apart from the frame on the end. The three types were `private` inside `MenuContentView.swift`; only `AgentListView` needs to be visible to the window controller, so the other two stay `private` in their new file.

```swift
import SwiftUI
import HerdPetCore

/// What every host is running: one section per host, most attention-worthy
/// agent first. This is the window's whole content. The one-second tick lives
/// here, since the elapsed timers are the only thing that moves on its own.
struct AgentListView: View {
    @ObservedObject var store: AgentStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                if let error = store.configError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.hostOrder.isEmpty {
                    Text("No hosts configured.\nEdit \(ConfigLoader.defaultPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.hostOrder, id: \.self) { host in
                    HostSection(host: host, store: store, now: context.date)
                }
            }
            .padding(12)
            // The popover was a fixed 360 wide; a window is whatever the user
            // drags it to, so the list fills the width and the rows spread.
            .frame(minWidth: 360, maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct HostSection: View {
    let host: String
    @ObservedObject var store: AgentStore
    let now: Date

    var body: some View {
        let agents = store.agents(forHost: host)
        let unreachable = store.unreachableHosts.contains(host)
        let names = AgentTitles.displayNames(for: agents)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(host).font(.headline)
                if unreachable {
                    Text("unreachable").font(.caption).foregroundStyle(.orange)
                }
            }
            if agents.isEmpty {
                Text(unreachable ? "cannot reach host" : "no agents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(agents, id: \.key) { agent in
                AgentRow(agent: agent, displayName: names[agent.key] ?? agent.info.displayName, now: now)
            }
        }
    }
}

private struct AgentRow: View {
    let agent: TrackedAgent
    let displayName: String
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            icon.frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName).font(.body).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(agent.status.rawValue).font(.caption)
            Circle().fill(agent.status.dotColor).frame(width: 8, height: 8)
            Text(TimerFormatter.string(from: agent.since, to: now))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var icon: some View {
        if let image = AgentIcons.image(for: AgentKind.from(label: agent.info.agent)) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "terminal").foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        let cwd = agent.info.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        return cwd.isEmpty ? agent.session : "\(agent.session) · \(cwd)"
    }
}
```

- [ ] **Step 2: Delete the old copies out of `MenuContentView.swift`**

Its `private struct AgentList`, `private struct HostSection` and `private struct AgentRow` are now duplicates of the code above and must go, or the file will not compile. Delete all three type declarations (`private struct AgentList` through the end of `private struct AgentRow`), keeping `MenuViewModel`, `MenuContentView`, `SettingsPage`, `Footer`, `PetPickerRow`, `PetSizeRow`, `AnimationSpeedRow` and `ClipBindingRows`.

Then change the one call site inside `MenuContentView.body`:

```swift
            case .agents:
                AgentListView(store: store)
```

- [ ] **Step 3: Create `MainWindowController.swift`**

```swift
import AppKit
import SwiftUI

/// The app's one window: the agent list in a normal title bar window that can be
/// resized, minimized and closed. Closing it must not quit the app — polling and
/// the menu bar item carry on — so `isReleasedWhenClosed` is off and
/// `AppDelegate` refuses to terminate with it.
@MainActor
final class MainWindowController {
    private static let frameAutosaveName = "herdpet.mainWindow"

    private let window: NSWindow

    init(store: AgentStore) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HerdPet"
        window.contentMinSize = NSSize(width: 360, height: 240)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: AgentListView(store: store))
        // Remember where the user put it. Without a saved frame the window lands
        // in the bottom-left corner, so the first launch centres it instead.
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        _ = window.setFrameAutosaveName(Self.frameAutosaveName)
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        window.makeKeyAndOrderFront(nil)
        // `activate(ignoringOtherApps:)` is deprecated from macOS 14, and this
        // package still deploys to 13.
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func hide() {
        window.orderOut(nil)
    }

    /// The menu bar item's action: show the window unless the user is already
    /// looking at it, in which case get out of the way.
    func toggle() {
        if isVisible && NSApp.isActive {
            hide()
        } else {
            show()
        }
    }
}
```

- [ ] **Step 4: Own and show the window in `AppDelegate`**

Add `private var mainWindow: MainWindowController?` next to the other stored properties, then insert this block in `applicationDidFinishLaunching`, immediately after the `do`/`catch` that loads the config:

```swift
        let window = MainWindowController(store: store)
        mainWindow = window
        window.show()
```

Leave everything else — `PetModel`, `PetWindowController`, the mood sink — alone for now.

- [ ] **Step 5: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Run it and look**

Run: `make run`
Expected: a window opens with the host sections and agent rows; it resizes, minimizes and closes. Closing it leaves the app and the pet running. Reopening from the Dock icon does not work yet — that is Task 3's `applicationShouldHandleReopen`; for now use the Dock icon's own menu or `open build/HerdPet.app`.

- [ ] **Step 7: Commit**

```bash
git add Sources/App/AgentListView.swift Sources/App/MainWindowController.swift Sources/App/MenuContentView.swift Sources/App/AppDelegate.swift
git commit -m "feat(app): show the agent list in a main window"
```

---

### Task 3: Make the menu bar item open the window, and delete the popover

**Files:**
- Modify: `Sources/App/StatusBarController.swift`
- Modify: `Sources/App/AppDelegate.swift`
- Delete: `Sources/App/MenuContentView.swift`

**Interfaces:**
- Consumes: `MainWindowController.toggle()`, `MainWindowController.show()` from Task 2.
- Produces: `StatusBarController(store:onToggle:)`, where `onToggle` is `@escaping () -> Void`.

- [ ] **Step 1: Rewrite `StatusBarController.swift`**

```swift
import AppKit
import Combine
import HerdPetCore

/// Menu bar item: a paw, plus an orange count while any agent is blocked.
/// Clicking toggles the window; the popover it used to show is gone, since the
/// window is now the whole UI and the popover was a worse copy of it.
@MainActor
final class StatusBarController: NSObject {
    private let store: AgentStore
    private let onToggle: () -> Void
    private var item: NSStatusItem?
    private var cancellable: AnyCancellable?

    init(store: AgentStore, onToggle: @escaping () -> Void) {
        self.store = store
        self.onToggle = onToggle
        super.init()
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "HerdPet")
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(toggle)
        self.item = item

        cancellable = store.$agents.sink { [weak self] _ in self?.refresh() }
        refresh()
    }

    private func refresh() {
        guard let button = item?.button else { return }
        let blocked = store.blockedCount
        if blocked > 0 {
            button.title = " \(blocked)"
            button.contentTintColor = .systemOrange
        } else {
            button.title = ""
            button.contentTintColor = nil
        }
    }

    @objc private func toggle() {
        onToggle()
    }
}
```

- [ ] **Step 2: Delete `MenuContentView.swift`**

```bash
git rm Sources/App/MenuContentView.swift
```

Everything left in it — `MenuViewModel`, `MenuContentView`, `SettingsPage`, `Footer`, `PetPickerRow`, `PetSizeRow`, `AnimationSpeedRow`, `ClipBindingRows` — drove the popover or configured the pet, and both are gone.

- [ ] **Step 3: Rewire `AppDelegate`**

Replace the status bar block:

```swift
        let bar = StatusBarController(store: store, pet: model)
        statusBar = bar
        bar.start()
```

with:

```swift
        let bar = StatusBarController(store: store) { [weak self] in
            self?.mainWindow?.toggle()
        }
        statusBar = bar
        bar.start()
```

Then add the two application-lifecycle methods, after `applicationWillTerminate`:

```swift
    /// Closing the window hides it. The herd keeps being polled and the menu bar
    /// item keeps working, so the last window closing must not end the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Clicking the Dock icon of an app with no visible windows asks for one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow?.show()
        return true
    }
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Run it and look**

Run: `make run`
Expected: clicking the paw shows the window, clicking it again hides it; with the window hidden and another app frontmost, clicking the paw brings the window up and activates the app; clicking the Dock icon reopens a closed window; the orange count still tracks blocked agents.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/StatusBarController.swift Sources/App/AppDelegate.swift
git commit -m "feat(app): open the window from the menu bar item and drop the popover"
```

---

### Task 4: Keep the highlight, moved into the agent store

A row tinted for three seconds when its agent turned `blocked` or `done` was the pet bubble's only signal that something had just changed. The window should keep it. `AgentStore` already sees the transitions, so the state moves there and the `onTransition` hook disappears.

**Files:**
- Modify: `Sources/App/AgentStore.swift`
- Modify: `Sources/App/AgentListView.swift`
- Modify: `Sources/App/AppDelegate.swift`

**Interfaces:**
- Consumes: `Transition` from `HerdPetCore` (unchanged).
- Produces: `AgentStore.highlighted: Set<String>` (published, read-only), `AgentStore.flash(agentKey:)`, `AgentStore.highlightSeconds`.

- [ ] **Step 1: Move the highlight into `AgentStore`**

In `Sources/App/AgentStore.swift`, delete this line:

```swift
    var onTransition: ((Transition) -> Void)?
```

Add these stored properties after `@Published var configError: String?`:

```swift
    /// Rows flashing because their agent just turned blocked or done.
    @Published private(set) var highlighted: Set<String> = []
```

and after the `bySession` property:

```swift
    /// How long a row stays tinted after its agent turns blocked or done.
    static let highlightSeconds: UInt64 = 3
    private var highlightTasks: [String: Task<Void, Never>] = [:]
```

Replace the tail of `apply(host:session:snapshot:now:)`:

```swift
        rebuild()
        for transition in result.transitions {
            onTransition?(transition)
        }
```

with:

```swift
        rebuild()
        // The store is where the transitions already are, so the tint is decided
        // here rather than by a hook the window would have to install.
        for transition in result.transitions {
            switch transition.to {
            case .blocked, .done: flash(agentKey: transition.agent.key)
            default: break
            }
        }
```

Add the `flash` method after `setReachable`:

```swift
    /// Tints one agent's row for `highlightSeconds`. Several rows can flash at
    /// once, and a second transition during a flash restarts its timer.
    func flash(agentKey: String) {
        highlighted.insert(agentKey)
        highlightTasks[agentKey]?.cancel()
        highlightTasks[agentKey] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.highlightSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.highlighted.remove(agentKey)
            self?.highlightTasks[agentKey] = nil
        }
    }
```

- [ ] **Step 2: Tint the row in `AgentListView.swift`**

Give `AgentRow` the flag, in its declaration:

```swift
private struct AgentRow: View {
    let agent: TrackedAgent
    let displayName: String
    let isHighlighted: Bool
    let now: Date
```

and add the tint at the end of its body, replacing the closing `.padding(.vertical, 2)` line with:

```swift
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(agent.status.dotColor.opacity(isHighlighted ? 0.22 : 0))
        )
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
    }
```

(The snippet starts at the existing `.padding(.vertical, 2)` line and runs to the end of
`body`, so that line ends up appearing exactly once.)

Then pass it from `HostSection`:

```swift
            ForEach(agents, id: \.key) { agent in
                AgentRow(agent: agent,
                         displayName: names[agent.key] ?? agent.info.displayName,
                         isHighlighted: store.highlighted.contains(agent.key),
                         now: now)
            }
```

- [ ] **Step 3: Drop the old wiring in `AppDelegate`**

Delete this block:

```swift
        store.onTransition = { transition in
            switch transition.to {
            case .blocked, .done: model.flash(agentKey: transition.agent.key)
            default: break
            }
        }
```

`PetModel.flash` and `PetModel.highlighted` are now unused. Leave them: the whole file goes in Task 5.

- [ ] **Step 4: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 5: Run it and look**

Run: `make run`
Expected: with a live agent, a row tints for about three seconds when that agent turns `blocked` or `done`, then fades back. The pet's bubble still tints too, since it still has its own copy of the state — that goes away with the bubble in Task 5.

- [ ] **Step 6: Commit**

```bash
git add Sources/App/AgentStore.swift Sources/App/AgentListView.swift Sources/App/AppDelegate.swift
git commit -m "feat(app): tint an agent's row when it turns blocked or done"
```

---

### Task 5: Delete the pet's App code

**Files:**
- Delete: `Sources/App/PetModel.swift`, `Sources/App/PetView.swift`, `Sources/App/PetWindowController.swift`, `Sources/App/PetLayout.swift`, `Sources/App/SpriteLayerView.swift`, `Sources/App/SpriteSlicer.swift`, `Sources/App/PetPackLoader.swift`
- Modify: `Sources/App/AppDelegate.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: an App target with no reference to the pet. `HerdPetCore`'s pet types are still present and now unused; Task 6 removes them.

- [ ] **Step 1: Delete the seven files**

```bash
git rm Sources/App/PetModel.swift Sources/App/PetView.swift Sources/App/PetWindowController.swift \
       Sources/App/PetLayout.swift Sources/App/SpriteLayerView.swift Sources/App/SpriteSlicer.swift \
       Sources/App/PetPackLoader.swift
```

- [ ] **Step 2: Strip the pet out of `AppDelegate`**

After this step the file reads, in full:

```swift
import AppKit
import Combine
import HerdPetCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AgentStore()
    private var monitor: Monitor?
    private var statusBar: StatusBarController?
    private var mainWindow: MainWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        MainMenu.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        var config = HerdPetConfig(pet: nil, clips: HerdPetConfig.defaultClips, hosts: [])
        do {
            config = try ConfigLoader.load()
        } catch {
            store.configError = "\(ConfigLoader.defaultPath): \(error)"
        }

        let window = MainWindowController(store: store)
        mainWindow = window
        window.show()

        let bar = StatusBarController(store: store) { [weak self] in
            self?.mainWindow?.toggle()
        }
        statusBar = bar
        bar.start()

        let monitor = Monitor(config: config, store: store)
        self.monitor = monitor
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }

    /// Closing the window hides it. The herd keeps being polled and the menu bar
    /// item keeps working, so the last window closing must not end the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Clicking the Dock icon of an app with no visible windows asks for one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow?.show()
        return true
    }
}
```

That is: all `petModel`, `petWindow`, `moodCancellable` and `PetModel`/`PetWindowController` references gone, along with the `store.$agents` sink that resolved the mood. The `HerdPetConfig(pet: nil, ...)` line keeps its old shape here and changes in Task 6, when the initializer does.

- [ ] **Step 3: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Run it and look**

Run: `make run`
Expected: the floating pet is gone; the window and the menu bar item behave as before.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/AppDelegate.swift
git commit -m "refactor(app): delete the floating pet"
```

---

### Task 6: Delete the pet's Core code and slim the config

**Files:**
- Delete: `Sources/HerdPetCore/Mood.swift`, `Sources/HerdPetCore/BubbleLines.swift`, `Sources/HerdPetCore/AnimationSpeed.swift`, `Sources/HerdPetCore/ClipBindings.swift`, `Sources/HerdPetCore/PetSize.swift`, `Sources/HerdPetCore/AgentBubbleRows.swift`
- Delete: `Tests/HerdPetCoreTests/MoodResolverTests.swift`, `Tests/HerdPetCoreTests/BubbleLinesTests.swift`, `Tests/HerdPetCoreTests/AnimationSpeedTests.swift`
- Modify: `Sources/HerdPetCore/HerdPetConfig.swift`
- Modify: `Tests/HerdPetCoreTests/ConfigLoaderTests.swift`
- Modify: `Sources/App/AppDelegate.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `HerdPetConfig(hosts: [HostConfig])` — the only initializer, with no `pet`, `clips`, `messages`, `defaultClips` or `clipIndex`.

- [ ] **Step 1: Delete the six Core files and the three test files**

```bash
git rm Sources/HerdPetCore/Mood.swift Sources/HerdPetCore/BubbleLines.swift \
       Sources/HerdPetCore/AnimationSpeed.swift Sources/HerdPetCore/ClipBindings.swift \
       Sources/HerdPetCore/PetSize.swift Sources/HerdPetCore/AgentBubbleRows.swift \
       Tests/HerdPetCoreTests/MoodResolverTests.swift Tests/HerdPetCoreTests/BubbleLinesTests.swift \
       Tests/HerdPetCoreTests/AnimationSpeedTests.swift
```

- [ ] **Step 2: Slim `HerdPetConfig`**

In `Sources/HerdPetCore/HerdPetConfig.swift`, replace the `HerdPetConfig` struct and its `defaultClips`/`clipIndex` members with:

```swift
public struct HerdPetConfig: Equatable, Sendable {
    public var hosts: [HostConfig]

    public init(hosts: [HostConfig]) {
        self.hosts = hosts
    }
}
```

`HostConfig`, `ConfigError` and `ConfigLoader`'s `defaultPath`, `defaultPollSeconds` and `load(path:)` are unchanged.

- [ ] **Step 3: Drop the pet keys from the parser**

In `ConfigLoader.parse(_:)`, delete the `let pet = doc.root["pet"]?.stringValue` line, the whole `var clips` loop and the whole `var messages` loop, and change the last line to:

```swift
        return HerdPetConfig(hosts: hosts)
```

Add this comment above the `var hosts` loop, so the next reader knows the removed keys are tolerated rather than accidentally forgotten:

```swift
        // `pet`, `[clips]` and `[messages]` are no longer read. They parse as
        // ordinary TOML and are ignored, so a config written for the pet still
        // loads; the README says they are gone.
        var hosts: [HostConfig] = []
```

- [ ] **Step 4: Update the default config in `AppDelegate`**

```swift
        var config = HerdPetConfig(hosts: [])
```

- [ ] **Step 5: Update `ConfigLoaderTests`**

These edits cannot be compiled on this machine (no `XCTest`), so make them carefully.

In `testFullSample`, leave the TOML text alone — its `pet = "boba"` and `[clips]` block now prove those keys are tolerated — and delete these five assertions:

```swift
        XCTAssertEqual(config.pet, "boba")
        XCTAssertEqual(config.clipIndex(for: .blocked), 3)
        XCTAssertEqual(config.clipIndex(for: .idle), 0)
        XCTAssertEqual(config.clipIndex(for: .working), 1)
        XCTAssertEqual(config.clipIndex(for: .done), 3)
```

Delete `testMessagesTable` and `testMessagesMustBeStringArrays` entirely: they test parsing that no longer exists.

In `testDefaultsWhenOptionalFieldsAbsent`, delete these three lines, leaving the `pollSeconds` assertion:

```swift
        XCTAssertNil(config.pet)
        XCTAssertEqual(config.clips, HerdPetConfig.defaultClips)
        XCTAssertTrue(config.messages.isEmpty)
```

In `testNoHostsIsValidButEmpty`, keep the `pet = "boba"` text and rename nothing; it now checks that a config holding only a removed key still parses to zero hosts.

- [ ] **Step 6: Build**

Run: `swift build`
Expected: `Build complete!`

This also proves nothing in the app target still referred to the deleted Core types; a leftover reference is the failure mode to watch for.

- [ ] **Step 7: Check nothing still names the pet**

Run: `grep -rn "Mood\|BubbleLines\|AnimationSpeed\|ClipBindings\|PetSize\|AgentBubbleRows\|SpriteSlicer\|PetPack\|PetLayout\|PetModel" Sources/ Tests/`
Expected: no output.

- [ ] **Step 8: Run it and look**

Run: `make run`
Expected: the app builds and runs as in Task 5.

- [ ] **Step 9: Commit**

```bash
git add -A Sources/HerdPetCore Tests/HerdPetCoreTests Sources/App/AppDelegate.swift
git commit -m "refactor(core): delete the pet's core types and config keys"
```

---

### Task 7: Say all of this in the README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the behaviour built in Tasks 1-6.
- Produces: documentation with no claim about the pet.

- [ ] **Step 1: Rewrite the description**

Replace the opening paragraph and the requirements bullet about pet packs so they describe a window instead of a floating pet. The opening paragraph becomes:

```markdown
# HerdPet

A macOS app that shows every coding agent running inside
[Herdr](https://herdr.dev), locally and on remote machines over SSH, in one
window, with a menu bar item carrying the number that are blocked.

State comes from Herdr's own detection (`agent.list` on each session's socket),
never from agent hooks. See `docs/adr/` for why.
```

- [ ] **Step 2: Drop the pet pack requirement**

Delete this bullet from the Requirements list:

```markdown
- One or more pet packs under `~/.agentpet/pets/<id>/` (AgentPet format).
  Without one, a pawprint placeholder is shown.
```

- [ ] **Step 3: Fix the config sample**

The sample keeps `pet` and `[clips]` out of it, since they do nothing now. It becomes a `[[hosts]]`-only sample, with a sentence above it noting that `pet`, `[clips]` and `[messages]` from an older config are ignored rather than an error.

- [ ] **Step 4: Replace the pet paragraph**

Replace the paragraph starting "The pet pack, how big the pet is drawn" and the one starting "The pet's bubble always lists" with a description of the window: one section per host, every agent, `name @ host` style rows showing status and elapsed time, the menu bar item showing and hiding the window, closing the window leaving the app running, and a row tinting for three seconds when its agent turns `blocked` or `done`.

- [ ] **Step 5: Read it back**

Run: `grep -n -i "pet" README.md`
Expected: only the paragraph explaining that `pet` is no longer a config key, and the app's own name.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: describe the window instead of the pet"
```

---

## Self-Review

**Spec coverage.** Every section of the spec has a task: activation policy and main menu → Task 1; main window, `contentMinSize`, autosave, close-hides, reopen → Tasks 2 and 3; status item toggle → Task 3; composition change → Tasks 2, 3 and 5; window content and the `MenuViewModel`/`SettingsPage`/`Footer` deletions → Tasks 2 and 3; Highlight and Transition → Task 4; the seven App and six Core deletions → Tasks 5 and 6; config surface → Task 6; domain language → done with the spec, before this plan; verification table → each task's build and run steps plus Task 6's grep; out of scope → nothing in this plan touches an app icon, the app's name, the config path or `~/.agentpet/pets`, and no task adds click-to-focus, notifications or a login item.

**Type consistency.** `AgentListView(store:)` is created in Task 2 and used in Task 3's deletion step; `MainWindowController.toggle()` and `.show()` are defined in Task 2 and called in Task 3; `AgentStore.flash(agentKey:)` and `highlighted` are defined in Task 4 and read by `AgentListView` in the same task; `HerdPetConfig(hosts:)` is defined in Task 6 and used by the `AppDelegate` line updated in the same task.

**Known gap, deliberately left.** The test target cannot be compiled on this machine, so Task 6's `ConfigLoaderTests` edits are verified by reading alone. The spec states this; Task 6 Step 5 says so again at the point of the edit.
