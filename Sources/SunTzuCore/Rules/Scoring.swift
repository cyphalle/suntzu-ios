/// Scoring phase and victory conditions — SPEC §5.7, §5.12.
public enum Scoring {
    /// True on turns 3, 6, 9 — SPEC §5.1.
    public static func isScoringTurn(_ turn: Int) -> Bool {
        return turn == 3 || turn == 6 || turn == 9
    }

    /// Compute scoreTrack delta for the current turn — SPEC §5.7.
    public static func computeDelta(_ state: GameState) -> Int {
        // TODO: implement in M5.
        return 0
    }

    /// Check if victory conditions are met — SPEC §5.12.
    public static func checkVictory(_ state: GameState) -> Player?? {
        // TODO: implement in M5. Returns .some(winner?) if game over, .none if ongoing.
        return nil
    }
}
