import AppKit
import SwiftUI

/// SwiftUI bridge to the CALayer-backed sprite player.
struct PetSpriteView: NSViewRepresentable {
    let frames: [NSImage]
    let fps: Double
    let size: CGFloat

    func makeNSView(context: Context) -> SpriteLayerNSView {
        let view = SpriteLayerNSView()
        view.configure(frames: frames, fps: fps)
        return view
    }

    func updateNSView(_ view: SpriteLayerNSView, context: Context) {
        view.configure(frames: frames, fps: fps)
    }

    static func dismantleNSView(_ view: SpriteLayerNSView, coordinator: ()) {
        view.teardown()
    }
}

/// Cycles CGImages by swapping `layer.contents` on a timer. SwiftUI is not
/// involved per frame, so an always-on pet costs almost nothing.
final class SpriteLayerNSView: NSView {
    private var cgFrames: [CGImage] = []
    private var sourceFrames: [NSImage] = []
    private var fps: Double = 3
    private var index = 0
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .linear
        layer?.contentsScale = window?.backingScaleFactor ?? 2
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func configure(frames: [NSImage], fps: Double) {
        let framesChanged = frames.count != sourceFrames.count
            || !zip(frames, sourceFrames).allSatisfy { $0 === $1 }
        if framesChanged {
            sourceFrames = frames
            cgFrames = frames.compactMap { $0.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            index = 0
        }
        let fpsChanged = fps != self.fps
        self.fps = fps
        if framesChanged || fpsChanged {
            restartTimer()
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        showCurrent()
        guard cgFrames.count > 1, fps > 0 else { return }
        let t = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advance() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func advance() {
        guard !cgFrames.isEmpty else { return }
        index = (index + 1) % cgFrames.count
        showCurrent()
    }

    private func showCurrent() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = cgFrames.isEmpty ? nil : cgFrames[index % cgFrames.count]
        CATransaction.commit()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contentsScale = window?.backingScaleFactor ?? 2
        CATransaction.commit()
    }

    func teardown() {
        timer?.invalidate()
        timer = nil
    }
}
