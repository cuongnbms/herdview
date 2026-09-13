import AppKit
import Combine
import HerdviewCore

/// Menu bar item: the herd mark, plus an orange count while any agent is blocked.
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
        item.button?.image = HerdMark.menuBarImage()
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
