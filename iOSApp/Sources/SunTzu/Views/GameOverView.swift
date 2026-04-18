import SwiftUI
import SunTzuCore

struct GameOverView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(title)
                    .font(.system(size: 44, weight: .thin, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.top, 40)

                Text(subtitle)
                    .font(.system(size: 20, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))

                summary
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer()

                Button("Retour au menu") {
                    GameStore.deleteSave()
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 40)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var title: String {
        switch Rules.winner(of: store.state) {
        case .some(GameStore.humanPlayer): return "Victoire"
        case .some(GameStore.aiPlayer):    return "Défaite"
        default:                           return "Match nul"
        }
    }

    private var subtitle: String {
        switch Rules.winner(of: store.state) {
        case .some(GameStore.humanPlayer): return "L'art de Sun Tzu t'a bien servi."
        case .some(GameStore.aiPlayer):    return "Le Roi Chu l'emporte cette fois."
        default:                           return "Les forces sont à l'équilibre."
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Score final", value: "\(store.state.scoreTrack)")
            row("Tours joués", value: "\(store.state.turn)")
            row("Pestes jouées", value: "\(store.state.pestesPlayedTotal)")
            row(
                "Réserve (vous / IA)",
                value: "\(store.state.players[.blue]?.reserve ?? 0) / \(store.state.players[.red]?.reserve ?? 0)"
            )
            row(
                "Cimetière (vous / IA)",
                value: "\(store.state.players[.blue]?.cemetery ?? 0) / \(store.state.players[.red]?.cemetery ?? 0)"
            )
        }
        .foregroundStyle(.white.opacity(0.85))
        .font(.callout)
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}
