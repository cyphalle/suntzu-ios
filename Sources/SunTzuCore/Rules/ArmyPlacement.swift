/// Army placement after combat — SPEC §5.6.4, §5.6.5.
public enum ArmyPlacement {
    /// Apply a combat delta to a province per cases A/B/C/D — SPEC §5.6.4.
    public static func applyCombatDelta(
        to state: GameState,
        province: Province,
        winner: Player,
        delta: Int
    ) throws -> GameState {
        // TODO: implement in M4.
        throw RulesError.notImplemented("ArmyPlacement.applyCombatDelta")
    }

    /// Place `count` armies in `province` for `player`, drawing first from
    /// reserve, then adjacent controlled provinces, then any controlled province.
    /// SPEC §5.6.5.
    public static func place(
        count: Int,
        player: Player,
        into province: Province,
        state: GameState,
        plan: [WithdrawalSource]? = nil
    ) throws -> GameState {
        // TODO: implement in M4.
        throw RulesError.notImplemented("ArmyPlacement.place")
    }
}
