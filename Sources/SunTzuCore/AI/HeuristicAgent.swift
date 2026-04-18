/// 1-ply greedy agent — applies each candidate action and keeps the one whose
/// resulting state scores highest for this player — SPEC §10.2.
/// Ties are broken uniformly at random (seeded).
public struct HeuristicAgent: GameAgent {
    public let player: Player
    private var rng: SeededRNG

    public init(player: Player, seed: UInt64) {
        self.player = player
        self.rng = SeededRNG(seed: seed)
    }

    public mutating func choose(in state: GameState, from actions: [GameAction]) -> GameAction {
        precondition(!actions.isEmpty, "HeuristicAgent.choose requires a non-empty action list")
        if actions.count == 1 { return actions[0] }

        var bestScore = -Double.infinity
        var best: [GameAction] = []
        for action in actions {
            let score: Double
            if let next = try? Rules.apply(action, to: state) {
                score = Evaluator.evaluate(next, for: player)
            } else {
                score = -Double.infinity
            }
            if score > bestScore {
                bestScore = score
                best = [action]
            } else if score == bestScore {
                best.append(action)
            }
        }
        if best.count == 1 { return best[0] }
        let idx = Int(rng.next() % UInt64(best.count))
        return best[idx]
    }
}
