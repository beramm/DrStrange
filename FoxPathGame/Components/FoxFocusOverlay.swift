import SwiftUI

/// Everything that tells the player where to look: a guide ring while the fox waits, and the
/// off-track warning when the pointer has left the fox.
///
/// The warning is a slow fade and a gentle breathing motion. Nothing flashes, and with
/// Reduce Motion the cues hold still.
struct FoxFocusOverlay: View {
    let viewModel: FoxPathGameViewModel
    let usesGaze: Bool

    var body: some View {
        let state = viewModel.trackingState
        let fox = viewModel.foxScreenPoint
        let height = viewModel.foxScreenHeight
        let bubbleSize = min(max(height * 0.36, 56), 96)

        ZStack {
            if state == .offTrack {
                DangerTint(center: fox, clearRadius: height * 0.8)
                    .transition(.opacity)
            }
            if state == .offTrack || state == .waiting {
                FocusRing(progress: viewModel.refocusProgress, isWarning: state == .offTrack)
                    .frame(width: height * 1.25, height: height * 1.25)
                    .position(fox)
                    .transition(.opacity)
            }
            if state == .offTrack {
                AlertBubble()
                    .frame(width: bubbleSize, height: bubbleSize)
                    .position(x: fox.x, y: max(fox.y - height * 0.5 - bubbleSize * 0.6, bubbleSize * 0.5 + 8))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            if let hint {
                Text(hint)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(FoxPathPalette.ink)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(.white.opacity(0.9)))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 36)
                    .transition(.opacity)
                    .id(hint)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state)
        .animation(.easeInOut(duration: 0.3), value: viewModel.needsPointer)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hint ?? "")
    }

    private var hint: String? {
        switch viewModel.trackingState {
        case .waiting:
            usesGaze ? "Look at the fox to start" : "Touch the fox to start"
        case .offTrack:
            usesGaze ? "Look at the fox!" : "Put your finger on the fox!"
        case .following:
            viewModel.needsPointer ? "Looking for your eye…" : nil
        case .finished:
            nil
        }
    }
}

/// Warm tint that closes in around the fox, leaving the fox itself clear.
private struct DangerTint: View {
    let center: CGPoint
    let clearRadius: CGFloat

    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [.clear, FoxPathPalette.danger.opacity(0.22), FoxPathPalette.danger.opacity(0.5)],
                        center: UnitPoint(x: center.x / max(size.width, 1), y: center.y / max(size.height, 1)),
                        startRadius: clearRadius,
                        endRadius: clearRadius * 3.4
                    )
                )
        }
        .opacity(isBreathing ? 0.7 : 1)
        // One breath takes about 2.4 s, far below any flicker rate.
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isBreathing)
        .onAppear { isBreathing = !reduceMotion }
    }
}

/// Ring around the fox that fills while the pointer rests on it.
private struct FocusRing: View {
    let progress: Double
    let isWarning: Bool

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [2, 16]))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(isWarning ? FoxPathPalette.danger : FoxPathPalette.guide, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.08), value: progress)
        }
        .scaleEffect(isPulsing ? 1.06 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear { isPulsing = !reduceMotion }
    }
}

/// "!" above the fox's head while it waits for the player.
private struct AlertBubble: View {
    @State private var isBobbing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(.white)
                Circle().strokeBorder(FoxPathPalette.danger, lineWidth: side * 0.08)
                Image(systemName: "exclamationmark")
                    .font(.system(size: side * 0.58, weight: .black, design: .rounded))
                    .foregroundStyle(FoxPathPalette.danger)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .offset(y: isBobbing ? -5 : 3)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBobbing)
        .onAppear { isBobbing = !reduceMotion }
    }
}

/// Small dot where the tracker (or the finger) is pointing.
struct FoxPointerMarker: View {
    let point: CGPoint

    var body: some View {
        Circle()
            .strokeBorder(.white, lineWidth: 3)
            .background(Circle().fill(FoxPathPalette.accent.opacity(0.65)))
            .frame(width: 30, height: 30)
            .shadow(radius: 3)
            .position(point)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
