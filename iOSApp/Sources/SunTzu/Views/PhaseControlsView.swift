import SwiftUI
import SunTzuCore

/// Bottom bar: contextual controls for the current phase.
struct PhaseControlsView: View {
    @Bindable var store: GameStore
    @Binding var selectedCard: Card?

    var body: some View {
        Group {
            switch store.state.phase {
            case .placement:
                placementControls
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

    // MARK: - Placement

    @ViewBuilder
    private var placementControls: some View {
        let drafts = store.humanDrafts.count
        let ready = store.canValidate

        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if selectedCard != nil {
                    Text("Tape une province (ou glisse la carte)")
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Désélectionner") { selectedCard = nil }
                        .tint(.white)
                } else {
                    Text(hint(drafts: drafts))
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text("\(drafts) / 5")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                Task {
                    selectedCard = nil
                    await store.validateDrafts()
                }
            } label: {
                Label("Valider les 5 placements", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ready ? Color.blue.opacity(0.9) : Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!ready)
        }
    }

    private func hint(drafts: Int) -> String {
        if drafts == 0 {
            return "Glisse une carte sur une province (ou tape pour sélectionner)"
        }
        if drafts < 5 {
            return "Il reste \(5 - drafts) province\(drafts == 4 ? "" : "s") à garnir"
        }
        return "Tout prêt — relis et valide"
    }

    // MARK: - Reveal

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

    // MARK: - Draw

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
}
