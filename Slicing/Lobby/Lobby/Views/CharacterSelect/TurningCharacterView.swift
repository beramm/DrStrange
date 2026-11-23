//
//  TurningCharacterView.swift
//  The character on the podium. It walks on the spot (four walking pictures,
//  again and again). When another character is chosen, it turns around:
//  side → back → other side, and halfway (at the back) it becomes the new
//  character, who finishes the turn and walks again.
//

import SwiftUI

struct TurningCharacterView: View {
    /// The chosen character.
    let character: GameCharacter
    /// Which way to spin: true for the next button, false for the previous one.
    let turnsRight: Bool

    private enum Pose {
        case walking
        case side(facingRight: Bool)
        case back
    }

    /// The character drawn right now. During a turn this is still the old
    /// character for the first half. nil = draw `character`.
    @State private var shown: GameCharacter?
    @State private var pose = Pose.walking
    @State private var turnTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long each walking picture stays on screen.
    private let secondsPerWalkFrame = 0.18
    /// How long each picture of the turn stays on screen.
    private let secondsPerTurnStep = 0.12

    var body: some View {
        let drawn = shown ?? character

        // The clock ticks every frame and picks the walking picture.
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            picture(of: drawn, at: context.date)
                .resizable()
                .scaledToFit()
                // The side picture faces right; mirror it to face left.
                .scaleEffect(x: isFacingLeft ? -1 : 1, y: 1)
        }
        .accessibilityElement()
        .accessibilityLabel(character.name)
        .onChange(of: character) { old, new in
            turn(from: old, to: new)
        }
        .onDisappear { turnTask?.cancel() }
    }

    private var isFacingLeft: Bool {
        if case .side(let facingRight) = pose { return !facingRight }
        return false
    }

    private func picture(of character: GameCharacter, at date: Date) -> Image {
        switch pose {
        case .walking:
            let frames = character.walkImageNames
            let step = Int(date.timeIntervalSinceReferenceDate / secondsPerWalkFrame)
            return Image(frames[step % frames.count])
        case .side:
            return Image(character.sideImageName)
        case .back:
            return Image(character.backImageName)
        }
    }

    /// The old character turns away, the new one turns to the front.
    private func turn(from old: GameCharacter, to new: GameCharacter) {
        turnTask?.cancel()
        guard !reduceMotion else {
            shown = nil
            pose = .walking
            return
        }
        let steps: [(GameCharacter, Pose)] = [
            (old, .side(facingRight: turnsRight)),
            (old, .back),
            (new, .side(facingRight: !turnsRight)),
        ]
        turnTask = Task {
            for (who, nextPose) in steps {
                shown = who
                pose = nextPose
                try? await Task.sleep(for: .seconds(secondsPerTurnStep))
                if Task.isCancelled { return }
            }
            shown = nil
            pose = .walking
        }
    }
}

#Preview {
    TurningCharacterView(character: .fox, turnsRight: true)
        .frame(width: 400, height: 400)
}
