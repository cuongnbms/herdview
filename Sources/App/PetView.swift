import SwiftUI
import HerdPetCore

struct PetView: View {
    static let size = CGSize(width: 240, height: 170)
    private static let sprite: CGFloat = 110

    @ObservedObject var model: PetModel

    var body: some View {
        VStack(spacing: 6) {
            bubble.frame(height: 44)
            sprite.frame(width: Self.sprite, height: Self.sprite)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    @ViewBuilder private var bubble: some View {
        if let text = model.bubbleText {
            Text(text)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 220)
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
