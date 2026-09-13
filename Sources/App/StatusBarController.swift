import AppKit

/// Menu bar item: the herd mark, and nothing else. Clicking toggles the window;
/// the popover it used to show is gone, since the window is now the whole UI and
/// the popover was a worse copy of it.
///
/// It used to carry the blocked count beside the mark, and tint both orange to
/// say so. In a status item that tint means handing the rendering back from the
/// menu bar to `contentTintColor`, and the bar then draws a template image in
/// the colours it was drawn in rather than in the bar's own — so an asking herd
/// came out black. The count went with it: the window says which agents are
/// asking and for how long, and the notification says it to someone who is not
/// looking, so a number in the bar was a third telling of the same news.
///
/// Nothing here observes the store, which is why there is no subscription and
/// no refresh: the item is built once and then only waits to be clicked.
@MainActor
final class StatusBarController: NSObject {
    private let onToggle: () -> Void
    private var item: NSStatusItem?

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        super.init()
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = HerdMark.menuBarImage()
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(toggle)
        self.item = item
    }

    @objc private func toggle() {
        onToggle()
    }
}
