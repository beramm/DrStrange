import SwiftUI

/// Minimal game list. The Lobby feature can replace this and link to `WhackAMoleSetupView`.
struct HomeView: View {
    #if DEBUG
    /// QA hook: launch with `-WhackAMoleAutostart` to open the game directly with the saved settings.
    @State private var isAutostarting = ProcessInfo.processInfo.arguments.contains("-WhackAMoleAutostart")
    #endif

    var body: some View {
        content
        #if DEBUG
            .fullScreenCover(isPresented: $isAutostarting) {
                WhackAMoleGameView(configuration: ConfigurationStore.standard.load()) { isAutostarting = false }
            }
        #endif
    }

    private var content: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("DrStrange")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(WhackAMolePalette.ink)

                NavigationLink {
                    WhackAMoleSetupView()
                } label: {
                    HStack(spacing: 24) {
                        Image(FoxHammerView.assetName(1))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Whack-a-Mole")
                                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                            Text("Tap the friends with a star")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.title.weight(.bold))
                    }
                    .foregroundStyle(WhackAMolePalette.ink)
                    .padding(28)
                    .frame(maxWidth: 640)
                    .background(RoundedRectangle(cornerRadius: 32).fill(WhackAMolePalette.cream))
                }
                .buttonStyle(.plain)

                Text("A game to support amblyopia care. It does not replace patching or any treatment prescribed by an eye doctor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WhackAMolePalette.meadow.ignoresSafeArea())
        }
    }
}
