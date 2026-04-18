import SwiftUI

struct MainMenuView: View {
    @State private var activeStore: GameStore?
    @State private var hasSave: Bool = GameStore.hasSave()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("Sun Tzu")
                    .font(.system(size: 56, weight: .thin, design: .serif))
                    .foregroundStyle(.white)
                Text("L'art de la guerre")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()

                menuButton("Nouvelle partie") {
                    activeStore = GameStore.newGame()
                }

                if hasSave {
                    menuButton("Reprendre") {
                        activeStore = GameStore.resume()
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 48)
        }
        .fullScreenCover(item: $activeStore) { store in
            NavigationStack {
                GameView(store: store)
            }
            .onDisappear { refreshSaveFlag() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.1))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func refreshSaveFlag() {
        hasSave = GameStore.hasSave()
    }
}

extension GameStore: Identifiable {
    public nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}
