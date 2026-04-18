import SwiftUI
import SunTzuCore

struct TopBarView: View {
    let store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Tour \(store.state.turn) / 9", systemImage: "flag.fill")
                Spacer()
                Text(phaseLabel)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .font(.subheadline)
            .foregroundStyle(.white)

            scoreTrack

            VStack(alignment: .leading, spacing: 4) {
                playerChip(player: .blue, color: .blue, title: "Vous")
                playerChip(player: .red, color: .red, title: "IA")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var phaseLabel: String {
        switch store.state.phase {
        case .placement:    return "Placement"
        case .reveal:       return "Révélation"
        case .scoring:      return "Décompte"
        case .draw:         return "Pioche"
        case .gameOver:     return "Terminé"
        }
    }

    private func playerChip(player: Player, color: Color, title: String) -> some View {
        let ps = store.state.players[player]
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(width: 54, alignment: .leading)
            counter(icon: "shield.fill", value: ps?.reserve ?? 0, tint: .white, label: "réserve")
            counter(icon: "xmark.seal.fill", value: ps?.cemetery ?? 0, tint: .white.opacity(0.85), label: "cimetière")
            counter(icon: "rectangle.stack.fill", value: ps?.hand.count ?? 0, tint: .white.opacity(0.75), label: "main")
            Spacer()
        }
        .foregroundStyle(.white)
        .font(.caption2)
    }

    private func counter(icon: String, value: Int, tint: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.caption2)
            Text("\(value)")
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(tint)
        .accessibilityLabel("\(label) \(value)")
    }

    private var scoreTrack: some View {
        GeometryReader { geo in
            let trackMax = 9
            let clampedTrack = max(-trackMax, min(trackMax, store.state.scoreTrack))
            let normalized = CGFloat(clampedTrack + trackMax) / CGFloat(2 * trackMax)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: normalized * geo.size.width)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 1, height: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                Text("\(store.state.scoreTrack)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .position(x: normalized * geo.size.width, y: geo.size.height / 2)
            }
        }
        .frame(height: 16)
    }
}
