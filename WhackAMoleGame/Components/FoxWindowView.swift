import SwiftUI

/// The fox's home: a small wooden window in the corner beside the board. The fox waits here,
/// leaves through it to attack, and comes back. Purely decorative; it never takes touches.
struct FoxWindowView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Shutters
                HStack(spacing: size.width * 0.84) {
                    shutter
                    shutter
                }
                .frame(height: size.height * 0.78)
                // Frame and warm interior
                RoundedRectangle(cornerRadius: size.width * 0.16)
                    .fill(WhackAMolePalette.rim)
                    .frame(width: size.width * 0.84, height: size.height * 0.92)
                RoundedRectangle(cornerRadius: size.width * 0.12)
                    .fill(WhackAMolePalette.windowInterior)
                    .frame(width: size.width * 0.72, height: size.height * 0.8)
            }
            .frame(width: size.width, height: size.height)
        }
        .anchorPreference(key: FoxAnchorKey.self, value: .bounds) { [.window: $0] }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var shutter: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(WhackAMolePalette.meadowDeep)
            .frame(width: 14)
    }
}

/// Front ledge of the window, drawn in front of the fox so it appears to sit inside.
struct FoxWindowSill: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(WhackAMolePalette.rim)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(WhackAMolePalette.holeShadow.opacity(0.35))
                    .frame(height: 4)
                    .padding(.horizontal, 8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
