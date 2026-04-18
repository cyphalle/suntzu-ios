/// Initial state constructors — SPEC §7.2, §5.1, §5.2.
public enum GameSetup {
    /// Build a fresh game state. Deterministic given `seed`.
    /// - Parameters:
    ///   - seed: xorshift64 RNG seed — SPEC §6.3.
    ///   - beginner: true → 21 armies in reserve, 18-card deck, no cemetery — SPEC §5.1.
    ///   - events: true → shuffle the 5-event deck — SPEC §5.10.
    public static func newGame(
        seed: UInt64,
        beginner: Bool = false,
        events: Bool = false
    ) -> GameState {
        var rng = SeededRNG(seed: seed)

        let bluePlayer = buildPlayer(owner: .blue, beginner: beginner, rng: &rng)
        let redPlayer = buildPlayer(owner: .red, beginner: beginner, rng: &rng)

        let emptyProvinces: [Province: ProvinceState] = Dictionary(
            uniqueKeysWithValues: Province.allCases.map { ($0, ProvinceState()) }
        )
        // Randomised per-province score displays: three values in [1, 5]
        // with a sum in [5, 10]. Resolves SPEC §13 Q#4.
        let displays: [Province: ScoreDisplay] = Dictionary(
            uniqueKeysWithValues: Province.allCases.map { province in
                (province, ScoreDisplay.random(using: &rng))
            }
        )

        var eventDeck: [EventCard] = events ? EventCard.allCases.shuffled(using: &rng) : []
        let firstEvent = events && !eventDeck.isEmpty ? eventDeck.removeFirst() : nil

        return GameState(
            turn: 1,
            phase: .placement,
            provinces: emptyProvinces,
            players: [.blue: bluePlayer, .red: redPlayer],
            scoreTrack: 0,
            scoreDisplays: displays,
            eventDeck: eventDeck,
            activeEvent: firstEvent
        )
    }

    /// Standard 20-card action deck — SPEC §5.2.
    /// Composition: 1× numeric 1..10, 3× +1, 1× +2, 1× +3, 3× -1, 2× plague.
    static func standardDeck(owner: Player) -> [Card] {
        var cards: [Card] = []
        for n in 1...10 {
            cards.append(Card(owner: owner, value: .numeric(n)))
        }
        for _ in 0..<3 { cards.append(Card(owner: owner, value: .bonus(1))) }
        cards.append(Card(owner: owner, value: .bonus(2)))
        cards.append(Card(owner: owner, value: .bonus(3)))
        for _ in 0..<3 { cards.append(Card(owner: owner, value: .malus)) }
        for _ in 0..<2 { cards.append(Card(owner: owner, value: .plague)) }
        return cards
    }

    /// Beginner 18-card deck — standard minus the +2 and +3 — SPEC §5.2.
    static func beginnerDeck(owner: Player) -> [Card] {
        standardDeck(owner: owner).filter { card in
            if case .bonus(let k) = card.value, k >= 2 { return false }
            return true
        }
    }

    // MARK: - private

    /// Build a single player's initial state:
    /// - 1..6 go straight to hand as permanent cards
    /// - remaining cards are shuffled into the deck
    /// - top 4 drawn into the hand → hand of 10
    /// SPEC §5.2.
    private static func buildPlayer(
        owner: Player,
        beginner: Bool,
        rng: inout SeededRNG
    ) -> PlayerState {
        let all = beginner ? beginnerDeck(owner: owner) : standardDeck(owner: owner)

        var permanents: [Card] = []
        var shufflable: [Card] = []
        for card in all {
            if case .numeric(let n) = card.value, (1...6).contains(n) {
                permanents.append(card)
            } else {
                shufflable.append(card)
            }
        }
        shufflable.shuffle(using: &rng)

        let drawn = Array(shufflable.prefix(4))
        let deck = Array(shufflable.dropFirst(4))
        let hand = permanents + drawn

        // Standard: 21 armies = 18 reserve + 3 cemetery.
        // Beginner: 21 armies = 21 reserve + 0 cemetery.
        let reserve = beginner ? 21 : 18
        let cemetery = beginner ? 0 : 3

        return PlayerState(
            hand: hand,
            deck: deck,
            reserve: reserve,
            cemetery: cemetery
        )
    }
}
