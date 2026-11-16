import SwiftUI

/// The fox's yellow card (the rounded frame behind the fox in the provided art), drawn on its own
/// so it can appear before the fox does. Colours and proportions are measured from the frames, so
/// when the fox image sits on top the two cards line up exactly.
///
/// Opens with a square reveal that follows the card's shape: the whole card grows from its centre
/// with a slight spring while a soft square ring ripples outward once. Purely decorative; it never takes touches.
struct FoxWindowView: View {
    /// 0 = hidden, 1 = full size. Slightly above 1 gives the springy overshoot.
    var reveal: Double = 1
    /// 0...1 progress of the ring that ripples out while the card opens; `nil` hides it.
    var ring: Double?

    static let fill = Color(red: 0.984, green: 0.800, blue: 0.400)
    static let border = Color(red: 0.957, green: 0.608, blue: 0.227)
    /// Corner radius and border width as a fraction of the card's width.
    static let cornerRatio: CGFloat = 0.055
    static let borderRatio: CGFloat = 0.018

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            RoundedRectangle(cornerRadius: size.width * Self.cornerRatio)
                .fill(Self.fill)
                .overlay(
                    RoundedRectangle(cornerRadius: size.width * Self.cornerRatio)
                        .strokeBorder(Self.border, lineWidth: size.width * Self.borderRatio)
                )
                .frame(width: size.width, height: size.height)
                // The whole card, border included, grows from its centre.
                .scaleEffect(max(reveal, 0))
                // The ring is a background so it never changes the card's size.
                .background {
                    if let ring {
                        let grow = 0.5 + 0.75 * ring
                        RoundedRectangle(cornerRadius: size.width * Self.cornerRatio * grow)
                            .stroke(Self.border, lineWidth: max(size.width * 0.03 * (1 - ring), 1))
                            .frame(width: size.width * grow, height: size.height * grow)
                            .opacity(0.6 * (1 - ring))
                    }
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
