//
//  CharacterPortrait.swift
//  The character's head and shoulders inside a blue circle.
//  The bottom of the body is cut off by the circle, but the ears may poke out above it.
//

import SwiftUI

struct CharacterPortrait: View {
    let imageName: String
    /// Width of the circle.
    let diameter: CGFloat
    /// Colour of the circle behind the character.
    var circleColor = Color.portraitBlue

    var body: some View {
        ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: diameter, height: diameter)

            // The full character image, enlarged and moved down so the head fills the circle.
            // Not mirrored: the characters face the front, and mirroring would move the
            // eye patch to the other eye.
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: diameter * 1.85, height: diameter * 1.85)
                .offset(y: diameter * 0.26)
        }
        .frame(width: diameter, height: diameter)
        .mask(PortraitMask())
        .accessibilityHidden(true)
    }
}

/// The circle, plus everything above the circle's middle line.
/// Anything below the middle is only shown inside the circle.
private struct PortraitMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        path.addRect(CGRect(x: rect.minX - rect.width, y: rect.minY - rect.height,
                            width: rect.width * 3, height: rect.height * 1.5))
        return path
    }
}
