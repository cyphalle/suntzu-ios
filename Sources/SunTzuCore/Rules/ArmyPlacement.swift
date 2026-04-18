/// Army placement after combat — SPEC §5.6.4, §5.6.5.
public enum ArmyPlacement {
    /// Apply a combat delta to `province` per cases A/B/C/D — SPEC §5.6.4.
    /// - Parameter plan: optional withdrawal plan for winner's army sources.
    ///   Used in cases A and D when winner needs to commit `delta` (A) or
    ///   `delta - n` (D) armies and reserve alone doesn't cover them.
    public static func applyCombatDelta(
        to state: GameState,
        province: Province,
        winner: Player,
        delta: Int,
        plan: [WithdrawalSource]? = nil
    ) throws -> GameState {
        guard var p = state.provinces[province] else {
            throw RulesError.malformedState("missing province \(province)")
        }
        let loser = winner.opponent
        let n = p.armies
        let ctrl = p.controller
        var newState = state

        // Case A: empty province or winner already controls.
        if ctrl == nil || ctrl == winner {
            // Cap the placement to what the winner can actually supply from
            // reserve + other controlled provinces. Shortfall is silently dropped.
            let actual = plan != nil ? delta : min(delta, armiesAvailable(for: winner, excluding: province, in: state))
            if actual <= 0 {
                return state
            }
            p.controller = winner
            p.armies += actual
            newState.provinces[province] = p
            return try place(
                count: actual, player: winner, into: province,
                state: newState, plan: plan
            )
        }

        // Otherwise ctrl == loser.
        if n > delta {
            // Case B: loser keeps control, loses `delta` armies to reserve.
            p.armies -= delta
            newState.provinces[province] = p
            try creditReserve(loser, by: delta, in: &newState)
            return newState
        } else if n == delta {
            // Case C: province wiped, all armies back to loser's reserve.
            p.armies = 0
            p.controller = nil
            newState.provinces[province] = p
            try creditReserve(loser, by: n, in: &newState)
            return newState
        } else {
            // Case D: n < delta. Loser recovers n, winner occupies with delta - n.
            try creditReserve(loser, by: n, in: &newState)
            let needed = delta - n
            let actual = plan != nil ? needed : min(needed, armiesAvailable(for: winner, excluding: province, in: state))
            if actual <= 0 {
                // Winner can't follow through; province is wiped.
                p.armies = 0
                p.controller = nil
                newState.provinces[province] = p
                return newState
            }
            p.controller = winner
            p.armies = actual
            newState.provinces[province] = p
            return try place(
                count: actual, player: winner, into: province,
                state: newState, plan: plan
            )
        }
    }

    /// Debit `count` armies from `player`'s sources to credit `province`.
    ///
    /// Without a plan: uses reserve only; throws if reserve is insufficient.
    /// With a plan: plan must sum to `count` and each source must be valid
    /// (controlled by `player`, enough armies, not the destination province).
    ///
    /// Sources (priority when auto-resolving — SPEC §5.6.5):
    /// 1. reserve
    /// 2. adjacent controlled provinces
    /// 3. any other controlled province
    ///
    /// SPEC §5.6.5: when multiple sources are possible, the choice must be
    /// explicit via `specifyWithdrawal`. The engine never auto-chooses between
    /// provinces.
    public static func place(
        count: Int,
        player: Player,
        into province: Province,
        state: GameState,
        plan: [WithdrawalSource]? = nil
    ) throws -> GameState {
        guard count >= 0 else {
            throw RulesError.malformedState("negative place count: \(count)")
        }
        if count == 0 { return state }

        var newState = state
        guard var ps = newState.players[player] else {
            throw RulesError.malformedState("missing player \(player)")
        }

        if let plan = plan {
            let total = plan.reduce(0) { acc, src in
                switch src {
                case .reserve(let c): return acc + c
                case .province(_, let c): return acc + c
                }
            }
            guard total == count else {
                throw RulesError.illegalAction(
                    "withdrawal plan total \(total) != required \(count)"
                )
            }
            for src in plan {
                switch src {
                case .reserve(let c):
                    guard c >= 0 else {
                        throw RulesError.malformedState("negative reserve count")
                    }
                    guard ps.reserve >= c else {
                        throw RulesError.illegalAction(
                            "reserve insufficient for \(player): have \(ps.reserve), need \(c)"
                        )
                    }
                    ps.reserve -= c
                case let .province(src, c):
                    guard c >= 0 else {
                        throw RulesError.malformedState("negative province count")
                    }
                    guard src != province else {
                        throw RulesError.illegalAction("cannot withdraw from destination \(province)")
                    }
                    guard var sp = newState.provinces[src] else {
                        throw RulesError.malformedState("missing province \(src)")
                    }
                    guard sp.controller == player else {
                        throw RulesError.illegalAction("\(src) not controlled by \(player)")
                    }
                    guard sp.armies >= c else {
                        throw RulesError.illegalAction(
                            "\(src) has \(sp.armies) armies, need \(c)"
                        )
                    }
                    sp.armies -= c
                    if sp.armies == 0 { sp.controller = nil }
                    newState.provinces[src] = sp
                }
            }
            newState.players[player] = ps
            return newState
        }

        // Default: canonical auto-resolution per SPEC §5.6.5 pseudo-algorithm:
        // 1) reserve, 2) adjacent controlled provinces, 3) any other controlled
        // province. DEFAULT: see SPEC §13 — ambiguous multi-source choices are
        // resolved canonically by Province.allCases order rather than asking
        // the user, until a withdrawal-pause phase is wired.
        let fromReserve = min(count, ps.reserve)
        ps.reserve -= fromReserve
        var remaining = count - fromReserve
        newState.players[player] = ps

        if remaining > 0 {
            let adjacent = Province.adjacency[province] ?? []
            for src in Province.allCases where adjacent.contains(src) && src != province {
                if remaining == 0 { break }
                guard var sp = newState.provinces[src], sp.controller == player, sp.armies > 0 else { continue }
                let take = min(remaining, sp.armies)
                sp.armies -= take
                if sp.armies == 0 { sp.controller = nil }
                newState.provinces[src] = sp
                remaining -= take
            }
        }
        if remaining > 0 {
            for src in Province.allCases where src != province {
                if remaining == 0 { break }
                guard var sp = newState.provinces[src], sp.controller == player, sp.armies > 0 else { continue }
                let take = min(remaining, sp.armies)
                sp.armies -= take
                if sp.armies == 0 { sp.controller = nil }
                newState.provinces[src] = sp
                remaining -= take
            }
        }
        if remaining > 0 {
            throw RulesError.illegalAction(
                "insufficient armies for \(player) to place \(count) into \(province) (short by \(remaining))"
            )
        }
        return newState
    }

    // MARK: - private

    private static func creditReserve(
        _ player: Player,
        by amount: Int,
        in state: inout GameState
    ) throws {
        guard var ps = state.players[player] else {
            throw RulesError.malformedState("missing player \(player)")
        }
        ps.reserve += amount
        state.players[player] = ps
    }

    /// Sum of armies the player can still commit to a new placement:
    /// reserve + every controlled province except the destination.
    private static func armiesAvailable(
        for player: Player,
        excluding destination: Province,
        in state: GameState
    ) -> Int {
        let reserve = state.players[player]?.reserve ?? 0
        let plateau = Province.allCases.reduce(0) { acc, province in
            guard province != destination,
                  let pv = state.provinces[province],
                  pv.controller == player else { return acc }
            return acc + pv.armies
        }
        return reserve + plateau
    }
}
