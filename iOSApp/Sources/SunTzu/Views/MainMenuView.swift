import SwiftUI

struct MainMenuView: View {
    @State private var activeStore: GameStore?
    @State private var hasSave: Bool = GameStore.hasSave()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Image("banner_title")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Text("Sun Tzu")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2)
                }
                .frame(height: 90)
                .padding(.horizontal, 24)

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
            ZStack {
                Image("button_brown")
                    .resizable(
                        capInsets: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14),
                        resizingMode: .stretch
                    )
                    .frame(height: 54)
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 1, y: 1)
            }
        }
    }

    private func refreshSaveFlag() {
        hasSave = GameStore.hasSave()
    }
}

extension GameStore: Identifiable {
    public nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}
