/// Heuristic evaluation of a `GameState` from one player's perspective — SPEC §10.2.
/// Higher = better for the player.
public enum Evaluator {
    public static func evaluate(_ state: GameState, for player: Player) -> Double {
        // Terminal outcomes dominate.
        if case .gameOver(let winner) = state.phase {
            if winner == player { return 100_000 }
            if winner == player.opponent { return -100_000 }
            return 0
        }

        let sign: Double = player == .blue ? 1 : -1
        var score: Double = sign * Double(state.scoreTrack) * 50

        // Province control × next-scoring-turn value, plus army buffer.
        let nextTurn = nextScoringTurn(state.turn)
        for province in Province.allCases {
            guard let pv = state.provinces[province] else { continue }
            let displayValue = Double(state.scoreDisplays[province]?.value(forTurn: nextTurn) ?? 0)
            // Fallback bias when displays are zeroed stubs — now with real
            // values this boost is minor relative to `displayValue`.
            let controlValue = displayValue * 3 + 1
            switch pv.controller {
            case .some(player):
                score += controlValue + Double(pv.armies) * 0.5
            case .some(player.opponent):
                score -= controlValue + Double(pv.armies) * 0.5
            default:
                break
            }
        }

        // Committed placements — reward committing strong cards on valuable
        // provinces as a proxy for expected combat wins. Without this term,
        // the hand-strength bonus below makes the heuristic hoard good cards
        // and lose combats by placing weaker ones.
        if case .placement = state.phase {
            for placement in state.placements {
                let displayValue = Double(state.scoreDisplays[placement.province]?.value(forTurn: nextTurn) ?? 0)
                let strength = cardStrength(placement.card.value)
                if placement.player == player {
                    score += strength * displayValue * 0.4 + strength * 0.2
                } else {
                    score -= strength * displayValue * 0.3 + strength * 0.1
                }
            }
        }

        // Reserve, cemetery (recoverable via .useRenfort, hence a smaller
        // positive weight than reserve), hand strength.
        if let ps = state.players[player] {
            score += Double(ps.reserve) * 0.6
            score += Double(ps.cemetery) * 0.3
            for card in ps.hand {
                score += cardStrength(card.value) * 0.05
            }
        }
        if let opp = state.players[player.opponent] {
            score -= Double(opp.reserve) * 0.4
            score -= Double(opp.cemetery) * 0.2
        }

        return score
    }

    // MARK: - private helpers

    private static func nextScoringTurn(_ turn: Int) -> Int {
        if turn <= 3 { return 3 }
        if turn <= 6 { return 6 }
        return 9
    }

    private static func cardStrength(_ value: CardValue) -> Double {
        switch value {
        case .numeric(let n): return Double(n)
        case .bonus(let k):   return 4 + Double(k)
        case .malus:          return 2
        case .plague:         return 5
        }
    }
}
