import SwiftUI
import SunTzuCore

/// Bottom bar: contextual controls for the current phase.
/// - Placement: instructs the human to pick a card + province.
/// - Reveal: "Reveal next combat" button.
/// - Draw: pick between the two top-of-deck cards.
struct PhaseControlsView: View {
    @Bindable var store: GameStore
    @Binding var selectedCard: Card?

    var body: some View {
        Group {
            switch store.state.phase {
            case .placement:
                placementHint
            case .reveal:
                revealControls
            case .draw:
                drawControls
            case .scoring, .gameOver:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var placementHint: some View {
        HStack(spacing: 8) {
            if selectedCard != nil {
                Text("Carte sélectionnée — tape une province")
                    .foregroundStyle(.white)
                Spacer()
                Button("Désélectionner") {
                    selectedCard = nil
                }
                .tint(.white)
            } else {
                Text("Choisis une carte dans ta main")
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("\(humanPlacementsLeft) à poser")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var revealControls: some View {
        Button {
            Task { await store.submitHumanAction(.revealNext) }
        } label: {
            Label("Révéler le combat suivant", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.9))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var drawControls: some View {
        if store.state.pendingDraws.contains(GameStore.humanPlayer) {
            let deck = store.state.players[GameStore.humanPlayer]?.deck ?? []
            if deck.isEmpty {
                Button("Passer (pioche vide)") {
                    Task { await store.submitHumanAction(.pass(player: GameStore.humanPlayer)) }
                }
                .tint(.white)
            } else if deck.count == 1 {
                Button {
                    Task {
                        await store.submitHumanAction(
                            .pickDrawCard(
                                player: GameStore.humanPlayer,
                                keep: deck[0],
                                bottom: nil
                            )
                        )
                    }
                } label: {
                    Text("Piocher la dernière carte")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                VStack(spacing: 6) {
                    Text("Garde une carte, place l'autre en bas du deck")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 8) {
                        drawChoice(keepIndex: 0, bottomIndex: 1)
                        drawChoice(keepIndex: 1, bottomIndex: 0)
                    }
                }
            }
        } else {
            Text("Tour de pioche de l'adversaire…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func drawChoice(keepIndex: Int, bottomIndex: Int) -> some View {
        let deck = store.state.players[GameStore.humanPlayer]?.deck ?? []
        let keep = deck[keepIndex]
        let bottom = deck[bottomIndex]
        return Button {
            Task {
                await store.submitHumanAction(
                    .pickDrawCard(player: GameStore.humanPlayer, keep: keep, bottom: bottom)
                )
            }
        } label: {
            VStack(spacing: 2) {
                Text("Garder")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                CardView(card: keep, isSelected: false)
            }
        }
    }

    private var humanPlacementsLeft: Int {
        5 - store.state.placements.filter { $0.player == GameStore.humanPlayer }.count
    }
}
