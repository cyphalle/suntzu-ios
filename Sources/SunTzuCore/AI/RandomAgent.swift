/// Baseline agent picking uniformly among `Rules.legalActions` — SPEC §10.1.
/// Deterministic for a given seed; mutation reflects RNG progress.
public struct RandomAgent: GameAgent {
    private var rng: SeededRNG

    public init(seed: UInt64) {
        self.rng = SeededRNG(seed: seed)
    }

    /// Returns a legal action, or nil if none are available (typically terminal).
    public mutating func chooseAction(in state: GameState) -> GameAction? {
        let actions = Rules.legalActions(in: state)
        guard !actions.isEmpty else { return nil }
        return choose(in: state, from: actions)
    }

    public mutating func choose(in state: GameState, from actions: [GameAction]) -> GameAction {
        precondition(!actions.isEmpty, "RandomAgent.choose requires a non-empty action list")
        let idx = Int(rng.next() % UInt64(actions.count))
        return actions[idx]
    }
}
