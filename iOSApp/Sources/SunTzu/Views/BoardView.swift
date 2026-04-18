import SwiftUI
import SunTzuCore

/// SwiftUI board — tiled Kenney parchment texture with five province
/// structures overlaid, connected by adjacency lines. Supports drag-drop
/// from the hand and the classic tap-card → tap-province flow.
struct BoardView: View {
    let state: GameState
    let humanDrafts: [Province: Card]
    @Binding var selectedCard: Card?
    var onProvinceTap: (Province) -> Void
    var onCardDropped: (UUID, Province) -> Void

    /// Relative positions in [0,1] for SwiftUI layout (y=0 at the top).
    private static let layout: [Province: CGPoint] = [
        .qin:    CGPoint(x: 0.28, y: 0.22),
        .jinYan: CGPoint(x: 0.72, y: 0.22),
        .hanQi:  CGPoint(x: 0.50, y: 0.50),
        .chu:    CGPoint(x: 0.28, y: 0.78),
        .wu:     CGPoint(x: 0.72, y: 0.78),
    ]

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) * 0.17
            ZStack {
                // Tiled parchment texture (Kenney medieval RTS tile_01).
                Image("board_texture")
                    .resizable(resizingMode: .tile)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .saturation(0.9)
                    .overlay(Color.black.opacity(0.15))

                Canvas { ctx, size in
                    ctx.stroke(adjacencyPath(in: size),
                               with: .color(.black.opacity(0.25)),
                               style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }

                ForEach(Province.allCases, id: \.self) { province in
                    let relative = Self.layout[province] ?? CGPoint(x: 0.5, y: 0.5)
                    ProvinceDiscView(
                        province: province,
                        pvState: state.provinces[province] ?? ProvinceState(),
                        display: state.scoreDisplays[province],
                        turn: state.turn,
                        draftCard: humanDrafts[province],
                        bluePlacedCommitted: committedPlacement(on: province, by: .blue),
                        redPlacedCommitted: committedPlacement(on: province, by: .red),
                        radius: radius
                    )
                    .position(
                        x: relative.x * geo.size.width,
                        y: relative.y * geo.size.height
                    )
                    .onTapGesture {
                        onProvinceTap(province)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let idString = items.first,
                              let uuid = UUID(uuidString: idString) else { return false }
                        onCardDropped(uuid, province)
                        return true
                    }
                }
            }
            .clipped()
            .cornerRadius(12)
        }
    }

    private func committedPlacement(on province: Province, by player: Player) -> Bool {
        state.placements.contains { $0.player == player && $0.province == province }
    }

    private func adjacencyPath(in size: CGSize) -> Path {
        var path = Path()
        for (from, targets) in Province.adjacency {
            guard let a = Self.layout[from] else { continue }
            for to in targets where from.hashValue < to.hashValue {
                guard let b = Self.layout[to] else { continue }
                path.move(to: CGPoint(x: a.x * size.width, y: a.y * size.height))
                path.addLine(to: CGPoint(x: b.x * size.width, y: b.y * size.height))
            }
        }
        return path
    }
}

// MARK: - ProvinceDiscView

/// One province on the SwiftUI board.
/// Kenney medieval RTS structure on top, armies under, six-marker badges,
/// score displays floating above, committed face-down chits below.
struct ProvinceDiscView: View {
    let province: Province
    let pvState: ProvinceState
    let display: ScoreDisplay?
    let turn: Int
    let draftCard: Card?
    let bluePlacedCommitted: Bool
    let redPlacedCommitted: Bool
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Disc backplate — coloured by controller.
            Circle()
                .fill(discFill)
                .overlay(Circle().stroke(discStroke, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .frame(width: radius * 2, height: radius * 2)

            // Score-display row anchored above the disc.
            scoreDisplayRow
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .offset(y: -radius - 6)

            VStack(spacing: -2) {
                Text(Self.displayName(province))
                    .font(.system(size: 11, weight: .heavy, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1)

                Image(Self.structureImage(for: province))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: radius * 1.1, height: radius * 1.1)

                if pvState.armies > 0 {
                    HStack(spacing: 2) {
                        Image(pvState.controller == .blue ? "unit_blue" : "unit_red")
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: radius * 0.35, height: radius * 0.35)
                        Text("\(pvState.armies)")
                            .font(.system(size: radius * 0.32, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 1)
                    }
                }
            }
            .frame(width: radius * 1.8, height: radius * 1.8)

            // Six-marker stars at the bottom corners.
            HStack {
                if pvState.sixMarkers.contains(.blue) {
                    sixBadge(color: .blue)
                }
                Spacer()
                if pvState.sixMarkers.contains(.red) {
                    sixBadge(color: .red)
                }
            }
            .frame(width: radius * 1.5)
            .offset(y: radius * 0.65)

            // Drafted card — face-up for the human.
            if let draftCard {
                draftBadge(for: draftCard)
                    .offset(y: -radius * 1.25)
            }

            // Committed face-down units beneath the disc.
            HStack(spacing: 6) {
                if bluePlacedCommitted {
                    Image("unit_blue")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
                if redPlacedCommitted {
                    Image("unit_red")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
            }
            .offset(y: radius + 16)
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private var scoreDisplayRow: some View {
        HStack(spacing: 3) {
            scoreValue(display?.t3, for: 3)
            separator
            scoreValue(display?.t6, for: 6)
            separator
            scoreValue(display?.t9, for: 9)
        }
    }

    private func scoreValue(_ value: Int?, for t: Int) -> some View {
        let isNext = nextScoringTurn(turn) == t
        return Text(value.map { "\($0)" } ?? "—")
            .font(.system(size: isNext ? 13 : 11,
                          weight: isNext ? .bold : .medium))
            .foregroundStyle(isNext ? Color.yellow : Color.white.opacity(0.65))
    }

    private var separator: some View {
        Text("·").font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
    }

    private func sixBadge(color: Color) -> some View {
        Image("marker_six")
            .resizable()
            .interpolation(.high)
            .frame(width: 18, height: 18)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .padding(-1)
            )
    }

    private func draftBadge(for card: Card) -> some View {
        Text(cardLabel(card.value))
            .font(.system(size: 18, weight: .bold, design: .serif))
            .foregroundStyle(cardColor(card.value))
            .frame(width: 34, height: 42)
            .background(Color.black.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(Color.yellow, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var discFill: Color {
        switch pvState.controller {
        case .blue: return Color.blue.opacity(0.40)
        case .red:  return Color.red.opacity(0.40)
        case nil:   return Color.black.opacity(0.25)
        }
    }
    private var discStroke: Color {
        switch pvState.controller {
        case .blue: return .blue
        case .red:  return .red
        case nil:   return .white.opacity(0.4)
        }
    }

    private func cardLabel(_ v: CardValue) -> String {
        switch v {
        case .numeric(let n): return "\(n)"
        case .bonus(let k):   return "+\(k)"
        case .malus:          return "-1"
        case .plague:         return "P"
        }
    }
    private func cardColor(_ v: CardValue) -> Color {
        switch v {
        case .numeric: return .white
        case .bonus:   return .green
        case .malus:   return .orange
        case .plague:  return .red
        }
    }

    private func nextScoringTurn(_ t: Int) -> Int {
        if t <= 3 { return 3 }
        if t <= 6 { return 6 }
        return 9
    }

    private static func displayName(_ p: Province) -> String {
        switch p {
        case .qin:    return "QIN"
        case .chu:    return "CHU"
        case .jinYan: return "JIN-YAN"
        case .hanQi:  return "HAN-QI"
        case .wu:     return "WU"
        }
    }

    private static func structureImage(for p: Province) -> String {
        switch p {
        case .qin:    return "province_qin"
        case .chu:    return "province_chu"
        case .jinYan: return "province_jinyan"
        case .hanQi:  return "province_hanqi"
        case .wu:     return "province_wu"
        }
    }
}
