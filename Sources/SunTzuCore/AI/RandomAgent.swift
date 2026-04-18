/// Baseline agent picking uniformly among `Rules.legalActions` — SPEC §10.1.
/// Deterministic for a given seed; mutation reflects RNG progress.
public struct RandomAgent: Sendable {
    private var rng: SeededRNG

    public init(seed: UInt64) {
        self.rng = SeededRNG(seed: seed)
    }

    /// Returns a legal action, or nil if none are available (typically in a terminal state).
    public mutating func chooseAction(in state: GameState) -> GameAction? {
        let actions = Rules.legalActions(in: state)
        guard !actions.isEmpty else { return nil }
        let idx = Int(rng.next() % UInt64(actions.count))
        return actions[idx]
    }
}
