import AppKit
import Combine
import SwiftUI
import HerdPetCore

/// Menu bar item: a paw, plus an orange count while any agent is blocked.
/// Clicking toggles a popover with `MenuContentView`.
@MainActor
final class StatusBarController: NSObject {
    private let store: AgentStore
    private let pet: PetModel
    private let menu = MenuViewModel()
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?

    init(store: AgentStore, pet: PetModel) {
        self.store = store
        self.pet = pet
        super.init()
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "HerdPet")
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(toggle)
        self.item = item

        popover.contentViewController = NSHostingController(
            rootView: MenuContentView(store: store, pet: pet, menu: menu)
        )
        popover.behavior = .transient

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
        guard let button = item?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
