/// Utility to pit two agents against each other in a full game.
public enum Arena {
    /// The player that owns a given action, or nil for engine-level actions
    /// (revealNext) that either side can dispatch.
    public static func actionOwner(_ action: GameAction) -> Player? {
        switch action {
        case let .placeCard(p, _, _),
             let .useStrategy(p, _, _),
             let .useRenfort(p, _),
             let .specifyWithdrawal(p, _),
             let .pickDrawCard(p, _, _),
             let .pass(p),
             let .chooseRevealOrder(p, _):
            return p
        case .revealNext:
            return nil
        }
    }

    /// Drive a full game between `blueAgent` and `redAgent`.
    /// Engine-level actions (revealNext) are dispatched automatically.
    /// Player-scoped actions go to the corresponding agent.
    public static func simulate<B: GameAgent, R: GameAgent>(
        seed: UInt64,
        beginner: Bool = false,
        events: Bool = false,
        blueAgent: inout B,
        redAgent: inout R,
        maxSteps: Int = 5000
    ) throws -> GameState {
        var state = GameSetup.newGame(seed: seed, beginner: beginner, events: events)
        var step = 0
        while !Rules.isTerminal(state) && step < maxSteps {
            let actions = Rules.legalActions(in: state)
            if actions.isEmpty { break }

            var blueActions: [GameAction] = []
            var redActions: [GameAction] = []
            var engineActions: [GameAction] = []
            for action in actions {
                switch actionOwner(action) {
                case .some(.blue): blueActions.append(action)
                case .some(.red): redActions.append(action)
                case .none: engineActions.append(action)
                }
            }

            let action: GameAction
            if !engineActions.isEmpty {
                action = engineActions[0]
            } else if case .placement = state.phase {
                // Alternate during placement: whoever has fewer placements plays next.
                let bluePlaced = state.placements.filter { $0.player == .blue }.count
                let redPlaced = state.placements.filter { $0.player == .red }.count
                let blueTurn = bluePlaced <= redPlaced && !blueActions.isEmpty
                if blueTurn {
                    action = blueAgent.choose(in: state, from: blueActions)
                } else if !redActions.isEmpty {
                    action = redAgent.choose(in: state, from: redActions)
                } else if !blueActions.isEmpty {
                    action = blueAgent.choose(in: state, from: blueActions)
                } else {
                    break
                }
            } else if !blueActions.isEmpty {
                action = blueAgent.choose(in: state, from: blueActions)
            } else {
                action = redAgent.choose(in: state, from: redActions)
            }

            state = try Rules.apply(action, to: state)
            step += 1
        }
        return state
    }
}
