import SwiftUI

/// The character shown on the patch reminder: the one the child picked on the character select
/// screen at the start.
enum PatchReminderCharacter: String, CaseIterable {
    case fox
    case bunny
    case raccoon

    /// Same key the character select screen saves the choice under (`GameCharacter.storageKey`).
    /// Kept as a plain string because the Fox Path app target does not include the lobby.
    static let storageKey = "selectedCharacterID"

    /// The saved choice, or the fox when nothing has been chosen yet.
    static func selected(in defaults: UserDefaults = .standard) -> PatchReminderCharacter {
        defaults.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? .fox
    }

    /// Frame with the patch over the eye (`isOn`) or lifted off it. Both frames of every
    /// character share one canvas, with the coloured disc in the same place.
    func frame(patchOn isOn: Bool) -> String {
        let name: String = switch self {
        case .fox: "Fox"
        case .bunny: "Bunny"
        case .raccoon: "Raccoon"
        }
        return "PatchReminder/\(name)Patch\(isOn ? "On" : "Off")"
    }
}

/// Full-screen warning shown while a game is paused because the camera sees both eyes (the patch
/// came off). Three copies of the chosen character keep lifting their patch and putting it back
/// on. The game hides this screen and carries on by itself once the one-eye check passes again.
///
/// To use it in another game: pause the game when `GazeInputController.patchWearState` becomes
/// `.missing`, show this screen while paused for that reason, and resume when the state becomes
/// `.verified` (see `WhackAMoleGameView.respondToPatchState`).
struct PatchReminderScreen: View {
    var character: PatchReminderCharacter = .selected()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The layout was drawn on a 1366 × 1024 point screen (iPad Pro 12.9" in landscape).
    private static let design = CGSize(width: 1366, height: 1024)
    static let sky = Color(red: 231 / 255, green: 245 / 255, blue: 252 / 255)
    static let brown = Color(red: 154 / 255, green: 97 / 255, blue: 56 / 255)

    /// One lift-and-replace of the patch: lifted for `liftDuration`, then back on for the rest.
    private static let cycle: TimeInterval = 1.6
    private static let liftDuration: TimeInterval = 0.55
    /// Each character starts its cycle this much after the one on its left.
    private static let stagger: TimeInterval = 0.25

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scale = min(size.width / Self.design.width, size.height / Self.design.height)
            ZStack {
                Self.sky
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    title(scale: scale)
                    Spacer(minLength: 0)
                    characters(scale: scale)
                    Spacer(minLength: 0)
                    message(scale: scale)
                    Spacer(minLength: 0)
                }
                .frame(height: size.height * 0.78)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
    }

    private func title(scale: CGFloat) -> some View {
        let fontSize = 75 * scale
        return Text("Do not forget to use your patch")
            .textCase(.uppercase)
            .font(.custom("DoodleChalkDemoRegular", size: fontSize))
            .tracking(fontSize * 0.025)
            .foregroundStyle(Self.brown)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 32)
            .accessibilityAddTraits(.isHeader)
    }

    private func message(scale: CGFloat) -> some View {
        Text("“Before you begin the adventure,\nmake sure to wear your eye patch!”")
            .font(.custom("DaysOne-Regular", size: 40 * scale))
            .foregroundStyle(Self.brown)
            .multilineTextAlignment(.center)
            .lineSpacing(2 * scale)
            .padding(.horizontal, 32)
    }

    /// Three copies of the character, 272-point discs 308 points apart as in the design.
    private func characters(scale: CGFloat) -> some View {
        let disc = 272 * scale
        // The disc fills 79% of the artwork's width; the ears stick out above it.
        let artSize = CGSize(width: disc / 0.79, height: disc / 0.79 * 840 / 880)
        return TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 308 * scale - artSize.width) {
                ForEach(0..<3, id: \.self) { index in
                    Image(character.frame(patchOn: reduceMotion || isPatchOn(at: time, index: index)))
                        .resizable()
                        .frame(width: artSize.width, height: artSize.height)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func isPatchOn(at time: TimeInterval, index: Int) -> Bool {
        let phase = (time - Double(index) * Self.stagger).truncatingRemainder(dividingBy: Self.cycle)
        return (phase < 0 ? phase + Self.cycle : phase) >= Self.liftDuration
    }
}

#Preview {
    PatchReminderScreen(character: .fox)
}
