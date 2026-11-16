import SwiftUI
import UIKit

/// Entry point of the standalone Paddy app. The internal target keeps its historical
/// `WhackAMoleGame` name, while the user experience starts in the shared lobby.
@main
struct WhackAMoleGameApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    updateIdleTimer(for: scenePhase)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    updateIdleTimer(for: newPhase)
                }
        }
    }

    /// Gaze play intentionally has long periods without touch input. Keep the
    /// display awake while Paddy is active, then restore normal iOS behaviour
    /// whenever the app leaves the foreground.
    private func updateIdleTimer(for phase: ScenePhase) {
        UIApplication.shared.isIdleTimerDisabled = phase == .active
    }
}
