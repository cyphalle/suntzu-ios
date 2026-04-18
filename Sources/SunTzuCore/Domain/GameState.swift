/// Score display values for a province at each scoring turn — SPEC §5.7, §6.1.
public struct ScoreDisplay: Hashable, Sendable, Codable {
    public let t3: Int
    public let t6: Int
    public let t9: Int

    public init(t3: Int, t6: Int, t9: Int) {
        self.t3 = t3
        self.t6 = t6
        self.t9 = t9
    }

    public func value(forTurn turn: Int) -> Int {
        switch turn {
        case 3: return t3
        case 6: return t6
        case 9: return t9
        default: return 0
        }
    }

    /// Sample one display: three values in [1, 5] whose sum lies in [5, 10].
    /// Rejection sampling — mean sum with uniform [1,5] is 9, so acceptance is high.
    public static func random(using rng: inout SeededRNG) -> ScoreDisplay {
        while true {
            let t3 = Int(rng.next() % 5) + 1
            let t6 = Int(rng.next() % 5) + 1
            let t9 = Int(rng.next() % 5) + 1
            let total = t3 + t6 + t9
            if (5...10).contains(total) {
                return ScoreDisplay(t3: t3, t6: t6, t9: t9)
            }
        }
    }
}

/// Per-province state — SPEC §6.1.
/// Invariant: controller == nil ⇔ armies == 0.
public struct ProvinceState: Hashable, Sendable, Codable {
    public var controller: Player?
    public var armies: Int
    /// Players who have already played their "6" marker in this province — SPEC §5.9 (double6).
    public var sixMarkers: Set<Player>

    public init(controller: Player? = nil, armies: Int = 0, sixMarkers: Set<Player> = []) {
        self.controller = controller
        self.armies = armies
        self.sixMarkers = sixMarkers
    }
}

/// Per-player state — SPEC §6.1.
public struct PlayerState: Hashable, Sendable, Codable {
    public var hand: [Card]
    public var deck: [Card]
    public var reserve: Int
    /// Cubes set aside in the "cemetery" pool — cards like +2 / +3 / numeric(6)
    /// send cubes here when revealed; a non-permanent discard can pull one back
    /// into `reserve` via `.useRenfort`. SPEC §5.11 + "gestion des troupes".
    public var cemetery: Int
    public var strategyCards: [StrategyCard]
    public var usedStrategies: Set<StrategyCard>
    public var sixesPlayed: Int

    public init(
        hand: [Card] = [],
        deck: [Card] = [],
        reserve: Int = 0,
        cemetery: Int = 0,
        strategyCards: [StrategyCard] = [],
        usedStrategies: Set<StrategyCard> = [],
        sixesPlayed: Int = 0
    ) {
        self.hand = hand
        self.deck = deck
        self.reserve = reserve
        self.cemetery = cemetery
        self.strategyCards = strategyCards
        self.usedStrategies = usedStrategies
        self.sixesPlayed = sixesPlayed
    }
}

/// A card placed on a province during the placement phase — SPEC §5.4.
public struct Placement: Hashable, Sendable, Codable {
    public let player: Player
    public let province: Province
    public let card: Card

    public init(player: Player, province: Province, card: Card) {
        self.player = player
        self.province = province
        self.card = card
    }
}

/// Phases of a single turn — SPEC §5.3.
public enum Phase: Hashable, Sendable, Codable {
    case placement
    case reveal(nextIndex: Int, order: [Province])
    case scoring
    case draw
    case gameOver(winner: Player?)
}

/// Full game state — SPEC §6.1.
/// All mutation goes through `Rules.apply(_:to:)`, which returns a new state.
public struct GameState: Hashable, Sendable, Codable {
    public var turn: Int                          // 1..9
    public var phase: Phase
    public var provinces: [Province: ProvinceState]
    public var players: [Player: PlayerState]
    public var scoreTrack: Int                    // positive = BLUE ahead, SPEC §5.7
    public var scoreDisplays: [Province: ScoreDisplay]
    public var revealPrivilegeHolder: Player?
    public var placements: [Placement]
    public var eventDeck: [EventCard]
    public var activeEvent: EventCard?
    public var pestesPlayedTotal: Int
    /// Players who still need to perform their draw this turn — SPEC §5.8.
    public var pendingDraws: Set<Player>
    /// Player owed a second strategy choice after the `charsDeGuerre` event fires — SPEC §5.10.
    public var pendingExtraStrategy: Player?

    public init(
        turn: Int,
        phase: Phase,
        provinces: [Province: ProvinceState],
        players: [Player: PlayerState],
        scoreTrack: Int,
        scoreDisplays: [Province: ScoreDisplay],
        revealPrivilegeHolder: Player? = nil,
        placements: [Placement] = [],
        eventDeck: [EventCard] = [],
        activeEvent: EventCard? = nil,
        pestesPlayedTotal: Int = 0,
        pendingDraws: Set<Player> = [],
        pendingExtraStrategy: Player? = nil
    ) {
        self.turn = turn
        self.phase = phase
        self.provinces = provinces
        self.players = players
        self.scoreTrack = scoreTrack
        self.scoreDisplays = scoreDisplays
        self.revealPrivilegeHolder = revealPrivilegeHolder
        self.placements = placements
        self.eventDeck = eventDeck
        self.activeEvent = activeEvent
        self.pestesPlayedTotal = pestesPlayedTotal
        self.pendingDraws = pendingDraws
        self.pendingExtraStrategy = pendingExtraStrategy
    }
}
