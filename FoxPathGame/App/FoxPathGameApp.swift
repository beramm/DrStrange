import SwiftUI

/// Entry point of the standalone `FoxPathGame` app. Excluded from the DrStrange target,
/// which shows the same game from its own home screen.
@main
struct FoxPathGameApp: App {
    var body: some Scene {
        WindowGroup {
            FoxPathEntryView()
        }
    }
}
