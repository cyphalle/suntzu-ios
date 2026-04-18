/// Common agent protocol — any strategy that can pick an action given a state.
/// Implementations carry seeded RNG state; mutation reflects progress.
public protocol GameAgent: Sendable {
    /// Pick one action among the provided non-empty list.
    mutating func choose(in state: GameState, from actions: [GameAction]) -> GameAction
}
