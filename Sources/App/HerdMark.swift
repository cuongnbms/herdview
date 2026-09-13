import AppKit

/// Herdview's mark: four agents, one of them asking for you.
///
/// It is the app icon and the menu bar item both, so it lives here rather than
/// in either one — `scripts/make-icon.swift` compiles this same file into the
/// icon tool. One layout, two mediums, and no way for the Dock and the menu bar
/// to drift apart.
///
/// The four nodes sit on a square. Three are quiet; the fourth is the one that
/// wants a person, and it is said three ways so that dropping any one of them
/// still leaves the mark readable: it is larger, it is the accent colour, and it
/// wears a ring. The menu bar gets only the first — a template image has no
/// colour to spend, and at 18pt a ring collapses into a grey smudge.
///
/// Nothing here is `@MainActor`: `NSImage`'s drawing handler may run off the
/// main thread, and the icon tool has no main actor at all.
enum HerdMark {

    enum Style {
        /// The Dock tile: dark squircle, the asking node in `accent`.
        case tile(accent: NSColor)
        /// The menu bar: silhouette only, for an `NSImage` marked `isTemplate`.
        case template
    }

    /// Draws the mark filling a `size` x `size` box at the origin of the
    /// current context.
    static func draw(size: CGFloat, style: Style) {
        switch style {
        case .tile(let accent):
            drawTile(size)
            drawNodes(size: size, gap: 0.180, radius: 0.0945,
                      // 0.40, not lower: at 16px a quieter grey sinks into
                      // the tile and the mark becomes one orange dot with no
                      // herd around it to be one of.
                      quiet: NSColor(white: 1, alpha: 0.40), lit: accent,
                      // Below 32px the ring has under a pixel of stroke to live
                      // in and only greys the node it is meant to single out.
                      ring: size >= 32 ? accent.withAlphaComponent(0.42) : nil,
                      glow: size * 0.085)
        case .template:
            // No tile to sit on, so the mark itself takes the room the tile
            // would have used. Alpha survives a template image — macOS tints
            // what is opaque and leaves the rest lighter — so the quiet three
            // stay quiet on the bar.
            drawNodes(size: size, gap: 0.220, radius: 0.115,
                      quiet: NSColor(white: 0, alpha: 0.55), lit: .black,
                      ring: nil, glow: 0)
        }
    }

    /// The asking node is `litScale` times the others. Big enough to win a
    /// glance, small enough that the four still read as one herd.
    private static let litScale: CGFloat = 1.32

    /// Index of the asking node in `positions`: the top right one, where a
    /// reader's eye lands first in the Dock.
    private static let litIndex = 1

    private static func positions(size: CGFloat, gap: CGFloat) -> [NSPoint] {
        let g = size * gap, c = size / 2
        return [NSPoint(x: c - g, y: c + g), NSPoint(x: c + g, y: c + g),
                NSPoint(x: c - g, y: c - g), NSPoint(x: c + g, y: c - g)]
    }

    private static func drawNodes(size: CGFloat, gap: CGFloat, radius: CGFloat,
                                  quiet: NSColor, lit: NSColor,
                                  ring: NSColor?, glow: CGFloat) {
        let points = positions(size: size, gap: gap)
        let r = size * radius
        let litR = r * litScale

        for (i, p) in points.enumerated() where i != litIndex {
            fillCircle(at: p, radius: r, quiet)
        }

        let litPoint = points[litIndex]
        if let ring {
            ring.setStroke()
            let path = NSBezierPath(ovalIn: NSRect(x: litPoint.x - litR * 1.5,
                                                   y: litPoint.y - litR * 1.5,
                                                   width: litR * 3, height: litR * 3))
            path.lineWidth = size * 0.026
            path.stroke()
        }

        if glow > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = lit.withAlphaComponent(0.85)
            shadow.shadowBlurRadius = glow
            shadow.shadowOffset = .zero
            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            fillCircle(at: litPoint, radius: litR, lit)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            fillCircle(at: litPoint, radius: litR, lit)
        }
    }

    private static func fillCircle(at p: NSPoint, radius: CGFloat, _ color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - radius, y: p.y - radius,
                                    width: radius * 2, height: radius * 2)).fill()
    }

    /// The tile the nodes sit on: near-black, lit from the top like every other
    /// icon in the Dock, with a hairline so its edge survives a dark wallpaper.
    private static func drawTile(_ size: CGFloat) {
        let path = squircle(size)
        let top = NSColor(srgbRed: 0x2A/255, green: 0x2A/255, blue: 0x31/255, alpha: 1)
        let bottom = NSColor(srgbRed: 0x0C/255, green: 0x0C/255, blue: 0x10/255, alpha: 1)
        NSGradient(colors: [top, bottom])?.draw(in: path, angle: -90)

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSColor(white: 1, alpha: 0.10).setStroke()
        let edge = squircle(size)
        edge.lineWidth = max(1, size * 0.012)
        edge.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func squircle(_ size: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                     xRadius: size * 0.225, yRadius: size * 0.225)
    }

    /// The menu bar item's image, and the only one there is.
    ///
    /// It does not change when an agent turns blocked. A status item's template
    /// image is rendered by the menu bar itself, which is what makes it read on
    /// a light bar and a dark one without being told which it is on; asking for
    /// `contentTintColor` on top of that takes the rendering away from the bar
    /// and puts back the mark in the colours it was drawn in — black, which is
    /// right for a mask and wrong for a bar. The count that used to sit beside
    /// it is gone with it; the window and the notification both already say
    /// which agents are asking.
    ///
    /// A drawing handler rather than a bitmap, so the bar redraws it at
    /// whatever scale the screen it moved to needs.
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(size: rect.width, style: .template)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Herdview"
        return image
    }
}
