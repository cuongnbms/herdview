import SwiftUI
import HerdPetCore

struct PetView: View {
    @ObservedObject var model: PetModel

    var body: some View {
        VStack(spacing: PetLayout.spacing) {
            bubble
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(.easeInOut(duration: 0.22), value: model.alert)
                .animation(.easeInOut(duration: 0.22), value: model.moodLine)
            sprite
                .frame(width: model.petPoint, height: model.petPoint)
        }
        .frame(width: model.panelSize.width, height: model.panelSize.height)
    }

    @ViewBuilder private var bubble: some View {
        if let alert = model.alert {
            ChatBubble(text: alert.text, detail: alert.detail)
                .transition(.opacity)
        } else if !model.moodLine.isEmpty {
            ChatBubble(text: model.moodLine)
                .transition(.opacity)
        } else if model.mood == .working {
            ChatBubble(text: "…", compact: true)
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

/// AgentPet's speech bubble: a capsule with a hairline border, a soft shadow,
/// and a small tail pointing down at the pet. `detail` adds a dimmer second
/// line and squares the corners a little.
struct ChatBubble: View {
    let text: String
    var detail: String? = nil
    var compact = false

    private var fill: Color { Color(nsColor: .textBackgroundColor) }
    private var radius: CGFloat { detail == nil ? 999 : 14 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                Text(text)
                    .font(.system(size: compact ? 10.5 : 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.primary.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 3 : 7)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
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

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
