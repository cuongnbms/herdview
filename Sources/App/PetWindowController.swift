import AppKit
import SwiftUI

/// Borderless floating panel hosting `PetView`. Draggable by its background;
/// the position is remembered in UserDefaults.
@MainActor
final class PetWindowController: NSObject, NSWindowDelegate {
    private static let originKey = "herdpet.petOrigin"
    private let panel: NSPanel

    init(model: PetModel) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: PetView.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isRestorable = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PetView(model: model))
        panel.delegate = self
        place()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func windowDidMove(_ notification: Notification) {
        let origin = panel.frame.origin
        UserDefaults.standard.set([origin.x, origin.y], forKey: Self.originKey)
    }

    private func place() {
        if let saved = UserDefaults.standard.array(forKey: Self.originKey) as? [Double], saved.count == 2 {
            panel.setFrameOrigin(NSPoint(x: saved[0], y: saved[1]))
            return
        }
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - PetView.size.width - 24, y: visible.minY + 24)
        panel.setFrameOrigin(origin)
    }
}
