import Foundation

/// Action card face value — SPEC §5.2, §6.1.
public enum CardValue: Hashable, Sendable, Codable {
    case numeric(Int)   // 1..10
    case bonus(Int)     // +1, +2, +3
    case malus          // -1
    case plague         // P

    /// Cards 1..6 are permanent (return to hand at end of turn) — SPEC §5.8.
    public var isKeepable: Bool {
        if case .numeric(let n) = self { return (1...6).contains(n) }
        return false
    }
}

/// A single action card owned by one player.
public struct Card: Hashable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let owner: Player
    public let value: CardValue

    public init(id: UUID = UUID(), owner: Player, value: CardValue) {
        self.id = id
        self.owner = owner
        self.value = value
    }
}

/// Strategy cards — SPEC §5.9.
public enum StrategyCard: String, Hashable, Sendable, Codable {
    // RED (Roi Chu)
    case double6
    case removeArmy
    case pesteTotal
    case pesteCounter
    case pesteBottomDiscard

    // BLUE (Sun Tzu)
    case moveArmy
    case count7to10As6
    case startBonus
    case malusBottomDiscard
    case reinforce
}

/// Optional event cards — SPEC §5.10.
public enum EventCard: String, CaseIterable, Hashable, Sendable, Codable {
    case pandemie
    case charsDeGuerre
    case defiChampion
    case defiHero
    case infanterieLegere
}
