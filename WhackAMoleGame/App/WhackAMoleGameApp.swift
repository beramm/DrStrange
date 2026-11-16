import SwiftUI

/// Entry point of the standalone Paddy app. The internal target keeps its historical
/// `WhackAMoleGame` name, while the user experience starts in the shared lobby.
@main
struct WhackAMoleGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
