/// Outcome of resolving a single combat (no plague) — SPEC §5.6.3.
public enum CombatOutcome: Hashable, Sendable {
    case tie
    case result(winner: Player, delta: Int)
    // TODO: plague outcomes added in M7 (SPEC §5.6.2).
}

/// Combat resolution — SPEC §5.6.
/// Pure functions; no state mutation.
public enum Combat {
    /// Effective value of `own` card against `opp` — SPEC §5.6.1.
    /// Plague paths return 0 as a placeholder — actual plague logic is M7.
    public static func effectiveValue(own: CardValue, opp: CardValue) -> Int {
        switch own {
        case .numeric(let n):
            return n
        case .bonus(let k):
            switch opp {
            case .numeric(let m): return m + k
            case .bonus: return k
            case .malus: return k
            case .plague: return 0 // M7
            }
        case .malus:
            switch opp {
            case .numeric(let m): return m - 1
            case .bonus: return 0
            case .malus: return -1
            case .plague: return 0 // M7
            }
        case .plague:
            return 0 // M7
        }
    }

    /// Resolve a combat between two cards, ignoring plague — SPEC §5.6.3.
    /// Returns the winner and delta, or .tie.
    public static func resolve(blue: Card, red: Card) -> CombatOutcome {
        // TODO: plague handling (SPEC §5.6.2) in M7. Until then, plague inputs
        // degenerate to 0-effective combat which is NOT spec-compliant.
        if blue.value == red.value {
            return .tie
        }
        let valB = effectiveValue(own: blue.value, opp: red.value)
        let valR = effectiveValue(own: red.value, opp: blue.value)
        if valB == valR {
            return .tie
        }
        let winner: Player = valB > valR ? .blue : .red
        let delta = abs(valB - valR)
        return .result(winner: winner, delta: delta)
    }
}
