/// Army placement after combat — SPEC §5.6.4, §5.6.5.
public enum ArmyPlacement {
    /// Apply a combat delta to `province` per cases A/B/C/D — SPEC §5.6.4.
    /// M3 implements Case A only (empty or winner-controlled province).
    /// Cases B/C/D land in M4.
    public static func applyCombatDelta(
        to state: GameState,
        province: Province,
        winner: Player,
        delta: Int
    ) throws -> GameState {
        guard var p = state.provinces[province] else {
            throw RulesError.malformedState("missing province \(province)")
        }
        let ctrl = p.controller

        if ctrl == nil || ctrl == winner {
            // Case A: winner gains `delta` armies on this province.
            var newState = state
            p.controller = winner
            p.armies += delta
            newState.provinces[province] = p
            return try place(
                count: delta,
                player: winner,
                into: province,
                state: newState
            )
        } else {
            // Cases B/C/D require the loser's controlled province to be touched.
            throw RulesError.notImplemented("applyCombatDelta cases B/C/D — M4")
        }
    }

    /// Debit `count` armies from the player's reserve (priority 1), then from
    /// adjacent controlled provinces, then any other controlled province — SPEC §5.6.5.
    /// The armies are assumed to have been credited to `province` by the caller;
    /// this function only handles the source side of the bookkeeping.
    ///
    /// M3 implements reserve-only (no withdrawal). M4 extends with the plan
    /// argument for explicit multi-source choices.
    public static func place(
        count: Int,
        player: Player,
        into province: Province,
        state: GameState,
        plan: [WithdrawalSource]? = nil
    ) throws -> GameState {
        guard var ps = state.players[player] else {
            throw RulesError.malformedState("missing player \(player)")
        }
        var remaining = count
        let fromReserve = min(remaining, ps.reserve)
        ps.reserve -= fromReserve
        remaining -= fromReserve

        var newState = state
        newState.players[player] = ps

        if remaining > 0 {
            // Withdrawal from adjacent/other controlled provinces — M4.
            throw RulesError.notImplemented("place: reserve exhausted, withdrawal needed — M4")
        }
        return newState
    }
}
