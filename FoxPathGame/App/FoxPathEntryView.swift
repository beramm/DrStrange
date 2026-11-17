import SwiftUI

/// Root of the standalone game: a navigation stack around the game home screen.
/// Host apps that already have a navigation stack should push `FoxPathHomeView` instead.
struct FoxPathEntryView: View {
    #if DEBUG
    /// QA hook: launch with `-FoxPathAutostart` to open the game directly with the saved
    /// settings and finger input (add `-FoxPathSimulatedGaze YES` for a pretend pointer).
    @State private var isAutostarting = ProcessInfo.processInfo.arguments.contains("-FoxPathAutostart")
    #endif

    var body: some View {
        NavigationStack {
            FoxPathHomeView()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $isAutostarting) {
            FoxPathGameView(configuration: FoxPathConfigurationStore.standard.load(), input: .touch) {
                isAutostarting = false
            }
        }
        #endif
    }
}
