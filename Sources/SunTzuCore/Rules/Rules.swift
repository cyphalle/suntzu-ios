/// Public rules engine — SPEC §7.1.
/// Pure functions over `GameState`. All mutations return a new state.
public enum Rules {
    /// All legal actions in the current state.
    public static func legalActions(in state: GameState) -> [GameAction] {
        // TODO: implement per SPEC §5.3, §12 M2+.
        return []
    }

    /// Apply an action, returning the new state. Throws if illegal.
    public static func apply(_ action: GameAction, to state: GameState) throws -> GameState {
        // TODO: implement per SPEC §5 and milestones M2..M8.
        throw RulesError.notImplemented("Rules.apply")
    }

    /// Whether the game has ended.
    public static func isTerminal(_ state: GameState) -> Bool {
        if case .gameOver = state.phase { return true }
        return false
    }

    /// The winner of a terminal state, nil for draws or in-progress games.
    public static func winner(of state: GameState) -> Player? {
        if case .gameOver(let winner) = state.phase { return winner }
        return nil
    }
}

/// Errors raised by the rules engine — SPEC §7.1.
public enum RulesError: Error, Equatable {
    case illegalAction(String)
    case malformedState(String)
    case notImplemented(String)
}
