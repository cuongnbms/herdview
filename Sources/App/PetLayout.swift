import CoreGraphics
import HerdPetCore

/// Turns the pet's size and the number of bubble lines into a panel size. The
/// panel is borderless and transparent, so its frame is exactly the content:
/// bubble on top, sprite below, nothing else.
enum PetLayout {
    /// The bubble keeps this width whatever the pet's size, so a 60pt pet is
    /// still readable. The panel is never narrower than the bubble.
    static let bubbleWidth: CGFloat = 240
    static let spacing: CGFloat = 2
    /// One agent row, or one line of chatter.
    static let lineHeight: CGFloat = 17
    static let bubbleInsetV: CGFloat = 7
    static let tailHeight: CGFloat = 7

    static func bubbleHeight(lines: Int) -> CGFloat {
        lines <= 0 ? 0 : CGFloat(lines) * lineHeight + bubbleInsetV * 2 + tailHeight
    }

    static func panelSize(petPoint: CGFloat, bubbleLines: Int) -> CGSize {
        let bubble = bubbleHeight(lines: bubbleLines)
        let height = bubble + (bubbleLines > 0 ? spacing : 0) + petPoint
        return CGSize(width: max(petPoint, bubbleWidth), height: height)
    }
}
