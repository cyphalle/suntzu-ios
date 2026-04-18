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
                    humanDrafts: store.humanDrafts,
                    selectedCard: $selectedCard,
                    onProvinceTap: handleProvinceTap,
                    onCardDropped: handleCardDrop
                )
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 8)

                HandView(
                    hand: handToShow,
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

    private var handToShow: [Card] {
        if case .placement = store.state.phase {
            return store.undraftedHand
        }
        return store.state.players[GameStore.humanPlayer]?.hand ?? []
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

    /// Tap flow:
    /// - Tap on a drafted province with no card selected → return the card to hand.
    /// - Tap on any province with a card selected → draft that card there
    ///   (replacing any existing draft).
    /// - Tap with neither selection nor draft → no-op.
    private func handleProvinceTap(_ province: Province) {
        guard case .placement = store.state.phase else { return }

        if let card = selectedCard {
            // Clear old draft if selecting a card already drafted on a different province.
            store.draft(card: card, to: province)
            selectedCard = nil
            return
        }
        if store.humanDrafts[province] != nil {
            store.clearDraft(at: province)
        }
    }

    /// Drag-drop flow: same semantics as draft — replaces any existing card
    /// on the target province.
    private func handleCardDrop(_ cardID: UUID, _ province: Province) {
        guard case .placement = store.state.phase else { return }
        guard let card = store.state.players[GameStore.humanPlayer]?
            .hand.first(where: { $0.id == cardID }) else { return }
        store.draft(card: card, to: province)
        selectedCard = nil
    }
}
