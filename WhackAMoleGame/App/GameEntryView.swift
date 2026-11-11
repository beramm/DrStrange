import SwiftUI

/// Root of the standalone game: a navigation stack around the game home screen.
/// Host apps that already have a navigation stack should push `GameHomeView` instead.
struct GameEntryView: View {
    #if DEBUG
    /// QA hook: launch with `-WhackAMoleAutostart` to open the game directly with the saved settings.
    @State private var isAutostarting = ProcessInfo.processInfo.arguments.contains("-WhackAMoleAutostart")
    #endif

    var body: some View {
        NavigationStack {
            GameHomeView()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $isAutostarting) {
            // Direct autostart intentionally remains touch-only for simulator animation QA.
            WhackAMoleGameView(configuration: ConfigurationStore.standard.load()) { isAutostarting = false }
        }
        #endif
    }
}
