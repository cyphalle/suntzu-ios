/// Public rules engine — SPEC §7.1.
/// Pure functions over `GameState`. All mutations return a new state.
public enum Rules {
    /// All legal actions in the current state.
    public static func legalActions(in state: GameState) -> [GameAction] {
        if case .gameOver = state.phase { return [] }

        switch state.phase {
        case .placement:
            return placementActions(in: state)
        default:
            // TODO: legalActions for reveal/scoring/draw in later milestones.
            return []
        }
    }

    /// Apply an action, returning the new state. Throws if illegal.
    public static func apply(_ action: GameAction, to state: GameState) throws -> GameState {
        switch action {
        case let .placeCard(player, province, card):
            return try applyPlaceCard(player: player, province: province, card: card, state: state)
        case .revealNext:
            return try applyRevealNext(state: state)
        default:
            throw RulesError.notImplemented("Rules.apply: \(action)")
        }
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

    // MARK: - Placement

    private static func placementActions(in state: GameState) -> [GameAction] {
        var actions: [GameAction] = []
        for player in [Player.blue, .red] {
            let usedProvinces = Set(
                state.placements.filter { $0.player == player }.map(\.province)
            )
            guard usedProvinces.count < 5 else { continue }
            let hand = state.players[player]?.hand ?? []
            for province in Province.allCases where !usedProvinces.contains(province) {
                for card in hand {
                    actions.append(.placeCard(player: player, province: province, card: card))
                }
            }
        }
        return actions
    }

    // MARK: - Reveal

    private static func applyRevealNext(state: GameState) throws -> GameState {
        guard case .reveal(let nextIndex, let order) = state.phase else {
            throw RulesError.illegalAction("revealNext outside reveal phase")
        }
        guard nextIndex < order.count else {
            throw RulesError.illegalAction("no more reveals in current order")
        }
        let province = order[nextIndex]
        let here = state.placements.filter { $0.province == province }
        guard let blue = here.first(where: { $0.player == .blue }),
              let red = here.first(where: { $0.player == .red }) else {
            throw RulesError.malformedState("expected one blue and one red placement on \(province)")
        }

        var newState = state
        switch Combat.resolve(blue: blue.card, red: red.card) {
        case .tie:
            break
        case let .result(winner, delta):
            newState = try ArmyPlacement.applyCombatDelta(
                to: newState,
                province: province,
                winner: winner,
                delta: delta
            )
        }

        let newIndex = nextIndex + 1
        if newIndex >= order.count {
            // End-of-reveal: auto-apply scoring on scoring turns, else go to draw.
            if Scoring.isScoringTurn(newState.turn) {
                newState = Scoring.applyScoringAndCheckVictory(newState)
            } else {
                newState.phase = .draw
            }
        } else {
            newState.phase = .reveal(nextIndex: newIndex, order: order)
        }
        return newState
    }

    // MARK: - Placement

    private static func applyPlaceCard(
        player: Player,
        province: Province,
        card: Card,
        state: GameState
    ) throws -> GameState {
        guard case .placement = state.phase else {
            throw RulesError.illegalAction("placeCard outside placement phase")
        }
        guard card.owner == player else {
            throw RulesError.illegalAction("cannot place opponent card")
        }
        let alreadyPlaced = state.placements.contains {
            $0.player == player && $0.province == province
        }
        guard !alreadyPlaced else {
            throw RulesError.illegalAction("\(player) already placed in \(province)")
        }
        guard var playerState = state.players[player] else {
            throw RulesError.malformedState("missing player \(player)")
        }
        guard let idx = playerState.hand.firstIndex(where: { $0.id == card.id }) else {
            throw RulesError.illegalAction("card \(card.id) not in \(player) hand")
        }

        var newState = state
        playerState.hand.remove(at: idx)
        newState.players[player] = playerState
        newState.placements.append(Placement(player: player, province: province, card: card))

        // Transition placement → reveal once 5+5 cards are down.
        if newState.placements.count == 10 {
            // DEFAULT: see SPEC §13 Q#3/§5.5 — for T1 the reveal order is fixed.
            // Turns 2+ privilege-holder choice is handled later (post-M6).
            newState.phase = .reveal(nextIndex: 0, order: Province.turn1RevealOrder)
        }
        return newState
    }
}

/// Errors raised by the rules engine — SPEC §7.1.
public enum RulesError: Error, Equatable {
    case illegalAction(String)
    case malformedState(String)
    case notImplemented(String)
}
