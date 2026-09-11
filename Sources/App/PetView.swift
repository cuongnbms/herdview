import SwiftUI
import HerdPetCore

struct PetView: View {
    @ObservedObject var model: PetModel

    var body: some View {
        VStack(spacing: PetLayout.spacing) {
            bubble
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(.easeInOut(duration: 0.22), value: model.bubble)
                .animation(.easeInOut(duration: 0.22), value: model.moodLine)
            sprite
                .frame(width: model.petPoint, height: model.petPoint)
        }
        // Fill the panel with the sprite at the bottom. A fixed frame the size of
        // `panelSize` sits at the top of the window for a beat after the panel
        // grows around the feet, so the pet jumps when the bubble gains a row.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder private var bubble: some View {
        if !model.bubble.rows.isEmpty {
            AgentListBubble(content: model.bubble, highlighted: model.highlighted)
                .transition(.opacity)
        } else if !model.moodLine.isEmpty {
            ChatBubble(text: model.moodLine)
                .transition(.opacity)
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var sprite: some View {
        let frames = model.frames(for: model.mood)
        if frames.isEmpty {
            Image(systemName: "pawprint.fill").font(.system(size: 36)).foregroundStyle(.secondary)
        } else {
            PetSpriteView(frames: frames, fps: model.fps(for: model.mood), size: model.petPoint)
        }
    }
}

/// The pet's bubble is light whatever the system appearance is. It floats over
/// a desktop the pet does not control, and the same text has to read on a dark
/// wallpaper as on a bright one.
private enum BubblePalette {
    static let fill = Color.white
    static let border = Color.black.opacity(0.08)
    static let strongText = Color.black.opacity(0.85)
    static let softText = Color.black.opacity(0.45)
}

/// The bubble the pet shows whenever any agent is blocked, working or done:
/// one row per agent, blocked first, with the rest summarised as "+N more".
struct AgentListBubble: View {
    let content: AgentBubbleContent
    let highlighted: Set<String>

    private var fill: Color { BubblePalette.fill }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(content.rows) { row in
                    AgentBubbleLine(row: row, isHighlighted: highlighted.contains(row.id))
                }
                if content.overflow > 0 {
                    Text("+\(content.overflow) more")
                        .font(.system(size: 10.5))
                        .foregroundStyle(BubblePalette.softText)
                        .frame(height: PetLayout.lineHeight, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, PetLayout.bubbleInsetV)
            .frame(width: PetLayout.bubbleWidth, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(BubblePalette.border, lineWidth: 1))
            .compositingGroup()
            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
            BubbleTail()
                .fill(fill)
                .frame(width: 12, height: PetLayout.tailHeight)
        }
    }
}

/// One agent in the bubble. The row tints for a few seconds when its agent has
/// just turned blocked or done, which is what replaced the old alert bubble.
private struct AgentBubbleLine: View {
    let row: AgentBubbleRow
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(row.status.dotColor).frame(width: 6, height: 6)
            Text(row.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BubblePalette.strongText)
                .lineLimit(1)
            Text("@ \(row.host)")
                .font(.system(size: 10.5))
                .foregroundStyle(BubblePalette.softText)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(-1)
            Spacer(minLength: 4)
            Text(row.status.rawValue)
                .font(.system(size: 10))
                .foregroundStyle(row.status.dotColor.opacity(0.9))
        }
        .padding(.horizontal, 4)
        .frame(height: PetLayout.lineHeight)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(row.status.dotColor.opacity(isHighlighted ? 0.22 : 0))
        )
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
    }
}

/// AgentPet's speech bubble: a capsule with a hairline border, a soft shadow,
/// and a small tail pointing down at the pet. `detail` adds a dimmer second
/// line and squares the corners a little.
struct ChatBubble: View {
    let text: String
    var detail: String? = nil
    var compact = false

    private var fill: Color { BubblePalette.fill }
    private var radius: CGFloat { detail == nil ? 999 : 14 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                Text(text)
                    .font(.system(size: compact ? 10.5 : 12, weight: .medium))
                    .foregroundStyle(BubblePalette.strongText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(BubblePalette.softText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 3 : 7)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(BubblePalette.border, lineWidth: 1))
            .compositingGroup()
            .shadow(color: .black.opacity(0.18), radius: compact ? 3 : 5, y: 2)
            BubbleTail()
                .fill(fill)
                .frame(width: compact ? 9 : 12, height: compact ? 5 : 7)
        }
        // Hug the text, but truncate at the bubble's fixed width, which does not
        // follow the pet's size: a 60pt pet still gets a readable bubble.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: PetLayout.bubbleWidth)
    }
}

struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
