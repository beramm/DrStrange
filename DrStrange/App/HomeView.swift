import SwiftUI

/// Minimal game list. The Lobby feature can replace this and push each game's home view.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("DrStrange")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(WhackAMolePalette.ink)

                NavigationLink {
                    GameHomeView()
                } label: {
                    GameCard(
                        imageName: FoxCharacterView.assetName(1),
                        title: "Whack-a-Mole",
                        subtitle: "Tap the friends with a star"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FoxPathHomeView()
                } label: {
                    GameCard(
                        imageName: FoxWalkAnimation.standingAsset,
                        title: "Follow the Fox",
                        subtitle: "Keep your eyes on the fox all the way home"
                    )
                }
                .buttonStyle(.plain)

                Text("Games to play while wearing the eye patch your child's eye doctor prescribed. They do not replace treatment or check-ups.")
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

private struct GameCard: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 24) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                Text(subtitle)
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
}
