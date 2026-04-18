/// Outcome of resolving a single combat — SPEC §5.6.
public enum CombatOutcome: Hashable, Sendable {
    case tie
    case result(winner: Player, delta: Int)
    /// Plague hits the province: armies are destroyed (floor/2, or all-but-1 with `pesteTotal`).
    /// SPEC §5.6.2.
    case plague(plaguePlayer: Player, pesteTotal: Bool)
}

/// Combat resolution — SPEC §5.6.
/// Pure functions; no state mutation.
public enum Combat {
    /// Effective value of `own` card against `opp` — SPEC §5.6.1.
    /// Plague paths return 0 as a placeholder; see `resolve` for plague handling.
    public static func effectiveValue(own: CardValue, opp: CardValue) -> Int {
        switch own {
        case .numeric(let n):
            return n
        case .bonus(let k):
            switch opp {
            case .numeric(let m): return m + k
            case .bonus: return k
            case .malus: return k
            case .plague: return 0
            }
        case .malus:
            switch opp {
            case .numeric(let m): return m - 1
            case .bonus: return 0
            case .malus: return -1
            case .plague: return 0
            }
        case .plague:
            return 0
        }
    }

    /// Resolve a combat, considering active strategy cards on both sides.
    ///
    /// Plague handling (SPEC §5.6.2):
    /// - Both plagues: DEFAULT §13 Q#5 — the blue (first-in-order) plague resolves,
    ///   the red one is discarded without effect.
    /// - One plague + opponent holds `pesteCounter`: plague is treated as numeric(0).
    ///   Combat is resolved normally between 0 and the opponent's card.
    /// - One plague, no counter: `.plague` outcome; `pesteTotal` toggled if plague
    ///   player holds it.
    ///
    /// Normal resolution applies `count7to10As6` to either side's numeric 7..10.
    public static func resolve(blue: Card, red: Card, state: GameState) -> CombatOutcome {
        let blueIsPlague = blue.value == .plague
        let redIsPlague = red.value == .plague

        let bluePlayer = state.players[.blue]
        let redPlayer = state.players[.red]
        let blueHoldsCounter = bluePlayer?.strategyCards.contains(.pesteCounter) ?? false
        let redHoldsCounter = redPlayer?.strategyCards.contains(.pesteCounter) ?? false
        let blueHoldsTotal = bluePlayer?.strategyCards.contains(.pesteTotal) ?? false
        let redHoldsTotal = redPlayer?.strategyCards.contains(.pesteTotal) ?? false
        let blueCountAs6 = bluePlayer?.strategyCards.contains(.count7to10As6) ?? false
        let redCountAs6 = redPlayer?.strategyCards.contains(.count7to10As6) ?? false

        if blueIsPlague && redIsPlague {
            // DEFAULT: see SPEC §13 Q#5 — blue (first in reveal order) resolves.
            return .plague(plaguePlayer: .blue, pesteTotal: blueHoldsTotal)
        }

        if blueIsPlague {
            if redHoldsCounter {
                let redVal = effectiveWithCountAs6(own: red.value, opp: .plague, count7to10As6: redCountAs6)
                return compare(blueVal: 0, redVal: redVal)
            }
            return .plague(plaguePlayer: .blue, pesteTotal: blueHoldsTotal)
        }

        if redIsPlague {
            if blueHoldsCounter {
                let blueVal = effectiveWithCountAs6(own: blue.value, opp: .plague, count7to10As6: blueCountAs6)
                return compare(blueVal: blueVal, redVal: 0)
            }
            return .plague(plaguePlayer: .red, pesteTotal: redHoldsTotal)
        }

        // No plague — normal path.
        if blue.value == red.value {
            return .tie
        }
        let blueVal = effectiveWithCountAs6(own: blue.value, opp: red.value, count7to10As6: blueCountAs6)
        let redVal = effectiveWithCountAs6(own: red.value, opp: blue.value, count7to10As6: redCountAs6)
        return compare(blueVal: blueVal, redVal: redVal)
    }

    // MARK: - private

    private static func effectiveWithCountAs6(own: CardValue, opp: CardValue, count7to10As6: Bool) -> Int {
        var adjusted = own
        if count7to10As6, case .numeric(let n) = own, (7...10).contains(n) {
            adjusted = .numeric(6)
        }
        return effectiveValue(own: adjusted, opp: opp)
    }

    private static func compare(blueVal: Int, redVal: Int) -> CombatOutcome {
        if blueVal == redVal { return .tie }
        let winner: Player = blueVal > redVal ? .blue : .red
        return .result(winner: winner, delta: abs(blueVal - redVal))
    }
}
