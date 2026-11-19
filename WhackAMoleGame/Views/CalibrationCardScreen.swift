import SwiftUI

/// The calibration card from the design: a cream card on a yellow background, a Doodle title,
/// two lines of text, a wooden NEXT button, and the carrot and onion houses.
/// Used before calibration ("Stare at the dots") and when a game needs calibration again.
///
/// Positions come from the 1366 × 1024 design frame and are scaled to the screen.
struct CalibrationCardScreen: View {
    let title: LocalizedStringKey
    let firstLine: LocalizedStringKey
    let secondLine: LocalizedStringKey
    let onNext: () -> Void

    static let design = CGSize(width: 1366, height: 1024)
    static let background = Color(red: 0.984, green: 0.890, blue: 0.682)
    static let titleBrown = Color(red: 0.600, green: 0.357, blue: 0.220)

    var body: some View {
        GeometryReader { geometry in
            let sx = geometry.size.width / Self.design.width
            let sy = geometry.size.height / Self.design.height
            let s = min(sx, sy)

            ZStack {
                Self.background.ignoresSafeArea()
                Self.card(sx: sx, sy: sy)

                Text(title)
                    .textCase(.uppercase)
                    .font(.custom("DoodleChalkDemoRegular", size: 92 * s))
                    .tracking(92 * s * 0.025)
                    .foregroundStyle(Self.titleBrown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 880 * sx)
                    .position(x: 683 * sx, y: 300 * sy)
                    .accessibilityAddTraits(.isHeader)

                Text(firstLine)
                    .font(.custom("DaysOne-Regular", size: 38 * s))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 860 * sx)
                    .position(x: 683 * sx, y: 455 * sy)

                Text(secondLine)
                    .font(.custom("DaysOne-Regular", size: 38 * s))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 860 * sx)
                    .position(x: 683 * sx, y: 567 * sy)

                Button(action: onNext) {
                    Image("ButtonBoard")
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            Text("Next")
                                .textCase(.uppercase)
                                .font(.custom("DoodleChalkDemoRegular", size: 62 * s))
                                .tracking(62 * s * 0.025)
                                .foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.88))
                                // The board's thick bottom edge: lift the word a little.
                                .offset(y: -6 * s)
                        }
                        .frame(width: 280 * s)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next")
                .position(x: 676 * sx, y: 735 * sy)

                Self.houses(carrot: CGRect(x: 130, y: 622, width: 155, height: 268),
                            onion: CGRect(x: 1030, y: 688, width: 180, height: 202),
                            sx: sx, sy: sy)
            }
        }
    }

    /// The cream card with the brown border.
    static func card(sx: CGFloat, sy: CGFloat) -> some View {
        Image("SettingsCard")
            .resizable()
            .frame(width: 962 * sx, height: 698 * sy)
            .position(x: 684 * sx, y: 511 * sy)
            .accessibilityHidden(true)
    }

    /// The carrot house bottom left and the onion house bottom right (rectangles in design points).
    static func houses(carrot: CGRect, onion: CGRect, sx: CGFloat, sy: CGFloat) -> some View {
        ZStack {
            Image("FoxPath/HouseCarrotFront")
                .resizable()
                .frame(width: carrot.width * sx, height: carrot.height * sy)
                .position(x: carrot.midX * sx, y: carrot.midY * sy)
            Image("FoxPath/HouseOnionFront")
                .resizable()
                .frame(width: onion.width * sx, height: onion.height * sy)
                .position(x: onion.midX * sx, y: onion.midY * sy)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The card shown in the middle of a game when eye control needs calibrating again.
struct RecalibrationNeededCard: View {
    let onNext: () -> Void

    var body: some View {
        CalibrationCardScreen(
            title: "Time to check again",
            firstLine: "The game is paused",
            secondLine: "Follow the dots, then keep playing",
            onNext: onNext
        )
    }
}

extension View {
    /// When eye control loses its calibration during a game: pauses the game, shows the
    /// "Time to check again" card, runs calibration again, and then carries on where it stopped.
    ///
    /// - Parameters:
    ///   - controller: the game's gaze controller. Nil (finger play) does nothing.
    ///   - isActive: false once the game has finished, so no card appears on the result screen.
    ///   - pause: pauses the game.
    ///   - resume: carries on from where the game was paused.
    func recalibratesWhenNeeded(
        controller: GazeInputController?,
        isActive: Bool,
        pause: @escaping () -> Void,
        resume: @escaping () -> Void
    ) -> some View {
        modifier(RecalibrationFlow(controller: controller, isActive: isActive, pause: pause, resume: resume))
    }
}

private struct RecalibrationFlow: ViewModifier {
    let controller: GazeInputController?
    let isActive: Bool
    let pause: () -> Void
    let resume: () -> Void

    /// The "Time to check again" card is showing.
    @State private var isAsking = false
    /// The calibration screens are showing.
    @State private var isCalibrating = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isAsking {
                    RecalibrationNeededCard { isCalibrating = true }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isAsking)
            .onChange(of: controller?.isCalibrated, initial: true) { _, isCalibrated in
                guard controller != nil, isCalibrated == false, isActive, !isAsking else { return }
                isAsking = true
                pause()
            }
            .fullScreenCover(isPresented: $isCalibrating) {
                if let controller {
                    GazeCalibrationView(
                        controller: controller,
                        isRecalibration: true,
                        onCalibrated: {
                            isCalibrating = false
                            isAsking = false
                            resume()
                        },
                        // Back to the card; NEXT tries again.
                        onCancel: { isCalibrating = false }
                    )
                }
            }
    }
}
