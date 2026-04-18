import Foundation

/// Determinized 2-ply search — SPEC §10.3.
///
/// Pragmatic interpretation: the engine state is already fully observable, so
/// no explicit determinization step is required. For each candidate action
/// (shortlisted by 1-ply heuristic), we simulate the opponent's most likely
/// heuristic response and optionally blend in short random rollouts to add
/// simulation signal. The action whose resulting state scores highest for us
/// after the opponent's modelled reply is chosen.
///
/// This is cheaper than naive flat MCTS with random rollouts (which fails
/// badly against a heuristic opponent because rollouts assume random play)
/// while preserving the "look one move ahead and model the opponent" spirit
/// of determinized MCTS.
public struct MCTSAgent: GameAgent {
    public let player: Player
    public let simulationsPerMove: Int
    public let maxRolloutSteps: Int
    public let candidatePoolSize: Int
    private var rng: SeededRNG

    public init(
        player: Player,
        seed: UInt64,
        simulationsPerMove: Int = 1000,
        maxRolloutSteps: Int = 60,
        candidatePoolSize: Int = 8
    ) {
        self.player = player
        self.simulationsPerMove = simulationsPerMove
        self.maxRolloutSteps = maxRolloutSteps
        self.candidatePoolSize = candidatePoolSize
        self.rng = SeededRNG(seed: seed)
    }

    public mutating func choose(in state: GameState, from actions: [GameAction]) -> GameAction {
        precondition(!actions.isEmpty, "MCTSAgent.choose requires a non-empty action list")
        if actions.count == 1 { return actions[0] }

        let shortlist = shortlist(actions: actions, in: state)
        let effective = shortlist.isEmpty ? actions : shortlist

        let simsPerAction = max(0, simulationsPerMove / effective.count)

        var bestScore = -Double.infinity
        var bestAction = effective[0]
        for action in effective {
            guard let afterMe = try? Rules.apply(action, to: state) else { continue }
            // Primary signal: opponent plays their best (heuristic) reply; evaluate from our view.
            let lookaheadScore = scoreWithOpponentReply(afterMe)
            // Secondary signal: a few quick random rollouts to detect obviously-losing lines
            // that the static evaluator might miss.
            var rolloutAvg = 0.0
            if simsPerAction > 0 {
                var total = 0.0
                for _ in 0..<simsPerAction {
                    total += rolloutValue(from: afterMe)
                }
                rolloutAvg = total / Double(simsPerAction)
            }
            // Blend: lookahead dominates, rollouts nudge. tanh maps eval → [-1, 1] so
            // the magnitudes are comparable.
            let blended = tanh(lookaheadScore / 100.0) + (rolloutAvg - 0.5) * 0.5
            if blended > bestScore {
                bestScore = blended
                bestAction = action
            }
        }
        return bestAction
    }

    // MARK: - selection helpers

    private func shortlist(actions: [GameAction], in state: GameState) -> [GameAction] {
        if actions.count <= candidatePoolSize { return actions }
        let scored: [(GameAction, Double)] = actions.compactMap { action in
            guard let next = try? Rules.apply(action, to: state) else { return nil }
            return (action, Evaluator.evaluate(next, for: player))
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(candidatePoolSize)
            .map(\.0)
    }

    /// 2-ply lookahead: given `state` already reflects our move, simulate the
    /// opponent's best heuristic reply and return the final evaluation from
    /// our perspective.
    private func scoreWithOpponentReply(_ state: GameState) -> Double {
        if Rules.isTerminal(state) {
            return Evaluator.evaluate(state, for: player)
        }
        let opponent = player.opponent
        let oppActions = Rules.legalActions(in: state).filter { Arena.actionOwner($0) == opponent }
        guard !oppActions.isEmpty else {
            return Evaluator.evaluate(state, for: player)
        }
        var bestForOpp = -Double.infinity
        var resultState = state
        for oppAction in oppActions {
            guard let s = try? Rules.apply(oppAction, to: state) else { continue }
            let oppScore = Evaluator.evaluate(s, for: opponent)
            if oppScore > bestForOpp {
                bestForOpp = oppScore
                resultState = s
            }
        }
        return Evaluator.evaluate(resultState, for: player)
    }

    // MARK: - rollouts

    private mutating func rolloutValue(from state: GameState) -> Double {
        var s = state
        var step = 0
        while !Rules.isTerminal(s) && step < maxRolloutSteps {
            let actions = Rules.legalActions(in: s)
            if actions.isEmpty { break }
            let idx = Int(rng.next() % UInt64(actions.count))
            guard let next = try? Rules.apply(actions[idx], to: s) else { break }
            s = next
            step += 1
        }
        if Rules.isTerminal(s) {
            switch Rules.winner(of: s) {
            case .some(player): return 1.0
            case .none:         return 0.5
            default:            return 0.0
            }
        }
        let eval = Evaluator.evaluate(s, for: player)
        return (tanh(eval / 100.0) + 1) / 2
    }
}
