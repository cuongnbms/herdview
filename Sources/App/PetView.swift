import SwiftUI
import HerdPetCore

struct PetView: View {
    static let size = CGSize(width: 240, height: 184)
    private static let sprite: CGFloat = 110
    private static let bubbleHeight: CGFloat = 58

    @ObservedObject var model: PetModel

    var body: some View {
        VStack(spacing: 2) {
            bubble
                .frame(height: Self.bubbleHeight, alignment: .bottom)
                .animation(.easeInOut(duration: 0.22), value: model.alert)
                .animation(.easeInOut(duration: 0.22), value: model.moodLine)
            sprite.frame(width: Self.sprite, height: Self.sprite)
        }
        .frame(width: Self.size.width, height: Self.size.height)
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
            PetSpriteView(frames: frames, fps: model.fps(for: model.mood), size: Self.sprite)
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
        // Hug the text, but let it truncate at the panel's width: the panel is
        // fixed-size, unlike AgentPet's content-sized bubble window.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: PetView.size.width - 8)
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
