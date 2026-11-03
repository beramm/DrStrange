//
// ContentView.swift
//  Lobby
//
//  Created by Keira on 03/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var path: [LobbyRoute] = []

    /// The child's chosen name, saved on the device so it survives app restarts.
    @AppStorage(Buddy.nameStorageKey) private var buddyName = Buddy.defaultName

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                HStack(spacing: geo.size.width * 0.06) {
                    // Left: character + editable name
                    CharacterCard(name: $buddyName, imageName: Buddy.imageName)
                        .frame(width: geo.size.width * 0.38)

                    // Right: actions
                    VStack(spacing: 28) {
                        Spacer()
                        KidButton(title: "Start", systemImage: "play.fill", kind: .primary) {
                            path.append(.gameSelect)
                        }
                        KidButton(title: "Settings", systemImage: "gearshape.fill", kind: .secondary) {
                            path.append(.settings)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: 380)
                }
                .padding(.horizontal, 48)
                .padding(.top, 32)
                // Extra bottom space: young children rest their wrists on the
                // bottom edge, so keep tappable things away from it.
                .padding(.bottom, 72)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(LobbyBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LobbyRoute.self) { route in
                switch route {
                case .gameSelect: GameSelectPlaceholder()
                case .settings:   SettingsPlaceholder()
                }
            }
        }
    }
}

#Preview("Lobby", traits: .landscapeLeft) {
    ContentView()
}
