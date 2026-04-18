import SwiftUI
import SunTzuCore

struct HandView: View {
    let hand: [Card]
    @Binding var selectedCard: Card?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(hand) { card in
                    CardView(card: card, isSelected: card.id == selectedCard?.id)
                        .onTapGesture {
                            selectedCard = (card.id == selectedCard?.id) ? nil : card
                        }
                        .draggable(card.id.uuidString) {
                            CardView(card: card, isSelected: true)
                        }
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

struct CardView: View {
    let card: Card
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Image("panel_brown")
                    .resizable(
                        capInsets: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14),
                        resizingMode: .stretch
                    )
                    .frame(width: 56, height: 86)
                    .overlay(
                        Rectangle()
                            .fill(background)
                            .blendMode(.overlay)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(textColor)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: 56, height: 86)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: isSelected ? 3 : 0)
            )

            if let cost = costLabel {
                HStack(spacing: 2) {
                    Text(cost)
                    Image(systemName: "xmark.seal.fill").font(.system(size: 8))
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .clipShape(Capsule())
                .offset(x: -4, y: 4)
            }
        }
        .offset(y: isSelected ? -8 : 0)
        .animation(.spring(duration: 0.2), value: isSelected)
    }

    private var label: String {
        switch card.value {
        case .numeric(let n): return String(n)
        case .bonus(let k):   return "+\(k)"
        case .malus:          return "-1"
        case .plague:         return "P"
        }
    }

    private var caption: String {
        switch card.value {
        case .numeric:      return "n"
        case .bonus:        return "bonus"
        case .malus:        return "malus"
        case .plague:       return "peste"
        }
    }

    private var textColor: Color {
        switch card.value {
        case .plague:       return .red
        case .malus:        return .orange
        case .bonus:        return .green
        case .numeric:      return .white
        }
    }

    private var background: Color {
        card.owner == .blue ? Color.blue.opacity(0.25) : Color.red.opacity(0.25)
    }

    /// Returns "-1" for a 1-troop cemetery cost, "-2" for a 2-troop cost, or nil
    /// for cards that don't send cubes to the cemetery on reveal.
    private var costLabel: String? {
        switch card.value {
        case .numeric(6):                      return "−1"
        case .bonus(let k) where k >= 2:       return "−\(k - 1)"
        default:                               return nil
        }
    }
}
