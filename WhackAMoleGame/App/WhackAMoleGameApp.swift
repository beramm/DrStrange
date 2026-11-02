import SwiftUI

/// Entry point of the standalone `WhackAMoleGame` app. Excluded from the DrStrange target,
/// which shows the same game from its own home screen.
@main
struct WhackAMoleGameApp: App {
    var body: some Scene {
        WindowGroup {
            GameEntryView()
        }
    }
}
