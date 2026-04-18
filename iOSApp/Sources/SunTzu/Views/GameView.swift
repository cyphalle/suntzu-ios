import SwiftUI
import SunTzuCore

struct GameView: View {
    @Bindable var store: GameStore
    @State private var selectedCard: Card?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            VStack(spacing: 12) {
                TopBarView(store: store)
                    .padding(.horizontal, 16)

                BoardView(
                    state: store.state,
                    selectedCard: $selectedCard,
                    onProvinceTap: handleProvinceTap
                )
                .frame(maxHeight: .infinity)

                HandView(
                    hand: store.state.players[GameStore.humanPlayer]?.hand ?? [],
                    selectedCard: $selectedCard
                )
                .frame(height: 110)

                PhaseControlsView(
                    store: store,
                    selectedCard: $selectedCard
                )
                .padding(.horizontal, 16)

                Spacer().frame(height: 6)
            }

            if store.isThinking {
                thinkingOverlay
            }
        }
        .navigationDestination(isPresented: .constant(Rules.isTerminal(store.state))) {
            GameOverView(store: store)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Menu") { dismiss() }
                    .tint(.white)
            }
        }
        .task {
            await store.advanceAutomatic()
        }
    }

    private var thinkingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.large)
            Text("L'adversaire réfléchit…")
                .foregroundStyle(.white.opacity(0.8))
                .font(.footnote)
        }
        .padding(24)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Interaction

    private func handleProvinceTap(_ province: Province) {
        guard case .placement = store.state.phase else { return }
        guard let card = selectedCard else { return }

        let alreadyPlaced = store.state.placements.contains {
            $0.player == GameStore.humanPlayer && $0.province == province
        }
        guard !alreadyPlaced else { return }

        Task {
            await store.submitHumanAction(
                .placeCard(player: GameStore.humanPlayer, province: province, card: card)
            )
            selectedCard = nil
        }
    }
}
