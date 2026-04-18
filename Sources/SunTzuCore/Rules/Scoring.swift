/// Scoring phase and victory conditions — SPEC §5.7, §5.12.
public enum Scoring {
    /// Absolute maximum for the scoreTrack — SPEC §5.1.
    public static let scoreTrackMax = 9

    /// True on turns 3, 6, 9.
    public static func isScoringTurn(_ turn: Int) -> Bool {
        turn == 3 || turn == 6 || turn == 9
    }

    /// Raw scoreTrack delta for the current turn: blueScore − redScore.
    /// Empty provinces contribute nothing.
    public static func computeDelta(_ state: GameState) -> Int {
        var blue = 0
        var red = 0
        for (province, ps) in state.provinces {
            guard let display = state.scoreDisplays[province] else { continue }
            let v = display.value(forTurn: state.turn)
            switch ps.controller {
            case .blue: blue += v
            case .red:  red += v
            case nil:   break
            }
        }
        return blue - red
    }

    /// Check end-of-game conditions against the current (already-updated) state.
    /// - Returns: the terminal phase `.gameOver(winner:)`, or `nil` if ongoing.
    ///
    /// SPEC §5.12 ordering:
    /// 1. T3/T6 early: |scoreTrack| == 9 → leader wins.
    /// 2. T9: always terminal; winner = sign of scoreTrack; tiebreak by reserve.
    public static func checkVictory(_ state: GameState) -> Phase? {
        if state.turn == 9 {
            return .gameOver(winner: determineWinner(state))
        }
        if abs(state.scoreTrack) >= scoreTrackMax {
            return .gameOver(winner: state.scoreTrack > 0 ? .blue : .red)
        }
        return nil
    }

    /// Compute delta, apply it to scoreTrack (clamped to ±9), and transition
    /// the phase to either `.gameOver(...)` or `.draw`.
    public static func applyScoringAndCheckVictory(_ state: GameState) -> GameState {
        var s = state
        let delta = computeDelta(s)
        let raw = s.scoreTrack + delta
        s.scoreTrack = max(-scoreTrackMax, min(scoreTrackMax, raw))
        if let terminal = checkVictory(s) {
            s.phase = terminal
        } else {
            s.phase = .draw
        }
        return s
    }

    // MARK: - private

    private static func determineWinner(_ state: GameState) -> Player? {
        if state.scoreTrack > 0 { return .blue }
        if state.scoreTrack < 0 { return .red }
        let b = state.players[.blue]?.reserve ?? 0
        let r = state.players[.red]?.reserve ?? 0
        if b > r { return .blue }
        if r > b { return .red }
        return nil // full draw
    }
}
