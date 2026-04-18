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
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(textColor)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 56, height: 86)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.yellow : Color.white.opacity(0.2), lineWidth: isSelected ? 3 : 1)
        )
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
}
