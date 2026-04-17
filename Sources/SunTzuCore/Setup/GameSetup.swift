/// Initial state constructors — SPEC §7.2, §5.2.
public enum GameSetup {
    /// Build a fresh game state. Deterministic given `seed`.
    /// - Parameters:
    ///   - seed: RNG seed (xorshift64) — SPEC §6.3.
    ///   - beginner: true → 21 armies, 18-card deck, no setAside — SPEC §5.1.
    ///   - events: true → enable optional event-card variant — SPEC §5.10.
    public static func newGame(
        seed: UInt64,
        beginner: Bool = false,
        events: Bool = false
    ) -> GameState {
        // TODO: implement in M1.
        // DEFAULT: see SPEC §13 Q#4 — score-display values not yet transcribed.
        let emptyProvinces: [Province: ProvinceState] = Dictionary(
            uniqueKeysWithValues: Province.allCases.map { ($0, ProvinceState()) }
        )
        let stubDisplays: [Province: ScoreDisplay] = Dictionary(
            uniqueKeysWithValues: Province.allCases.map { ($0, ScoreDisplay(t3: 0, t6: 0, t9: 0)) }
        )
        return GameState(
            turn: 1,
            phase: .placement,
            provinces: emptyProvinces,
            players: [.blue: PlayerState(), .red: PlayerState()],
            scoreTrack: 0,
            scoreDisplays: stubDisplays
        )
    }

    /// Standard 20-card action deck — SPEC §5.2.
    static func standardDeck(owner: Player) -> [Card] {
        // TODO: implement in M1.
        return []
    }

    /// Beginner 18-card action deck (no +2, no +3) — SPEC §5.2.
    static func beginnerDeck(owner: Player) -> [Card] {
        // TODO: implement in M1.
        return []
    }
}
