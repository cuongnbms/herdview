import AppKit
import Combine
import SwiftUI

/// Borderless floating panel hosting `PetView`. Draggable by its background;
/// the position is remembered in UserDefaults. The panel resizes with the pet
/// and with the bubble, keeping the pet's feet where they are.
@MainActor
final class PetWindowController: NSObject, NSWindowDelegate {
    /// Bottom-centre of the panel, not its origin: resizing must not move the
    /// pet, and the origin of a growing panel does.
    private static let anchorKey = "herdpet.petAnchor"
    private let panel: NSPanel
    private let model: PetModel
    private var sizeCancellable: AnyCancellable?

    init(model: PetModel) {
        self.model = model
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: model.panelSize),
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
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // NSHostingView swallows mouse-down, which would block
        // isMovableByWindowBackground. Hit-through lets the panel drag.
        panel.contentView = HitThroughHostingView(rootView: PetView(model: model))
        panel.delegate = self
        place()
        sizeCancellable = model.$panelSize.sink { [weak self] size in
            self?.resize(to: size)
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func windowDidMove(_ notification: Notification) {
        saveAnchor()
    }

    // MARK: Geometry

    /// Grows or shrinks around the pet's feet: bottom-centre stays put, and the
    /// result is kept on screen.
    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0, panel.frame.size != size else { return }
        let anchor = NSPoint(x: panel.frame.midX, y: panel.frame.minY)
        let origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y)
        panel.setFrame(onScreen(NSRect(origin: origin, size: size)), display: true)
    }

    private func place() {
        let size = panel.frame.size
        if let saved = UserDefaults.standard.array(forKey: Self.anchorKey) as? [Double], saved.count == 2 {
            let origin = NSPoint(x: saved[0] - size.width / 2, y: saved[1])
            panel.setFrame(onScreen(NSRect(origin: origin, size: size)), display: false)
            return
        }
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - size.width - 24, y: visible.minY + 24)
        panel.setFrameOrigin(origin)
    }

    private func saveAnchor() {
        let frame = panel.frame
        UserDefaults.standard.set([frame.midX, frame.minY], forKey: Self.anchorKey)
    }

    /// Nudges a frame back inside the screen it mostly sits on, so a pet grown
    /// at the edge of the display stays reachable.
    private func onScreen(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.max { a, b in
            a.frame.intersection(frame).area < b.frame.intersection(frame).area
        } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return frame }
        var result = frame
        result.origin.x = min(max(result.minX, visible.minX), max(visible.maxX - result.width, visible.minX))
        result.origin.y = min(max(result.minY, visible.minY), max(visible.maxY - result.height, visible.minY))
        return result
    }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

/// SwiftUI hosting views eat hits; returning nil lets the panel drag by its background.
private final class HitThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
