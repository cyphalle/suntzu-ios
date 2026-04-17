/// Event-card triggers evaluated after each combat resolution — SPEC §5.10, §5.6.6.
public enum EventTriggers {
    /// Inspect state after a resolved combat and apply any event effects
    /// whose trigger conditions are now met. Reveals the next event card
    /// if the current one has been consumed.
    public static func applyPostCombatEvents(_ state: GameState) throws -> GameState {
        // TODO: implement in M7/M8.
        return state
    }
}
