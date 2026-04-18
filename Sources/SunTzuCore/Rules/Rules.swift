import Foundation

/// Public rules engine — SPEC §7.1.
/// Pure functions over `GameState`. All mutations return a new state.
public enum Rules {
    /// All legal actions in the current state.
    public static func legalActions(in state: GameState) -> [GameAction] {
        if case .gameOver = state.phase { return [] }

        switch state.phase {
        case .placement:
            return placementActions(in: state)
        case .reveal:
            return [.revealNext]
        case .draw:
            return drawActions(in: state)
        case .scoring, .gameOver:
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
        case let .pickDrawCard(player, keep, bottom):
            return try applyPickDrawCard(player: player, keep: keep, bottom: bottom, state: state)
        case let .pass(player):
            return try applyPass(player: player, state: state)
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
            // End-of-reveal: run scoring first on scoring turns; if still alive,
            // fall through to the draw phase setup.
            if Scoring.isScoringTurn(newState.turn) {
                newState = Scoring.applyScoringAndCheckVictory(newState)
            }
            if case .draw = newState.phase {
                newState = enterDrawPhase(newState)
            } else if !Scoring.isScoringTurn(newState.turn) {
                newState = enterDrawPhase(newState)
            }
        } else {
            newState.phase = .reveal(nextIndex: newIndex, order: order)
        }
        return newState
    }

    // MARK: - Draw

    /// Enter the draw phase: step 1 returns permanents (numeric 1..6) to hand,
    /// discards other played cards, and marks both players as pending their pick.
    /// SPEC §5.8.
    static func enterDrawPhase(_ state: GameState) -> GameState {
        var s = state
        for placement in s.placements {
            if placement.card.value.isKeepable {
                guard var ps = s.players[placement.player] else { continue }
                ps.hand.append(placement.card)
                s.players[placement.player] = ps
            }
            // Non-permanents are removed from play (no discard pile exists).
        }
        s.placements.removeAll()
        s.pendingDraws = [.blue, .red]
        s.phase = .draw
        return s
    }

    private static func drawActions(in state: GameState) -> [GameAction] {
        var actions: [GameAction] = []
        for player in state.pendingDraws {
            guard let ps = state.players[player] else { continue }
            switch ps.deck.count {
            case 0:
                actions.append(.pass(player: player))
            case 1:
                actions.append(.pickDrawCard(player: player, keep: ps.deck[0], bottom: nil))
            default:
                let top = ps.deck[0]
                let second = ps.deck[1]
                actions.append(.pickDrawCard(player: player, keep: top, bottom: second))
                actions.append(.pickDrawCard(player: player, keep: second, bottom: top))
            }
        }
        return actions
    }

    private static func applyPickDrawCard(
        player: Player,
        keep: Card,
        bottom: Card?,
        state: GameState
    ) throws -> GameState {
        guard case .draw = state.phase else {
            throw RulesError.illegalAction("pickDrawCard outside draw phase")
        }
        guard state.pendingDraws.contains(player) else {
            throw RulesError.illegalAction("\(player) is not pending a draw")
        }
        guard keep.owner == player else {
            throw RulesError.illegalAction("cannot draw opponent card")
        }
        guard var ps = state.players[player] else {
            throw RulesError.malformedState("missing player \(player)")
        }

        switch ps.deck.count {
        case 0:
            throw RulesError.illegalAction("cannot pickDrawCard from empty deck; use .pass instead")
        case 1:
            guard bottom == nil else {
                throw RulesError.illegalAction("bottom must be nil when deck has exactly 1 card")
            }
            guard keep.id == ps.deck[0].id else {
                throw RulesError.illegalAction("keep card does not match the only deck card")
            }
            ps.deck.removeFirst()
            ps.hand.append(keep)
        default:
            guard let bottom = bottom else {
                throw RulesError.illegalAction("bottom required when deck has 2+ cards")
            }
            let topIds: Set<UUID> = [ps.deck[0].id, ps.deck[1].id]
            guard topIds.contains(keep.id),
                  topIds.contains(bottom.id),
                  keep.id != bottom.id else {
                throw RulesError.illegalAction("keep/bottom must be the two distinct top-of-deck cards")
            }
            ps.deck.removeFirst(2)
            ps.hand.append(keep)
            ps.deck.append(bottom)
        }

        var newState = state
        newState.players[player] = ps
        newState.pendingDraws.remove(player)
        if newState.pendingDraws.isEmpty {
            newState = advanceToNextTurn(newState)
        }
        return newState
    }

    private static func applyPass(player: Player, state: GameState) throws -> GameState {
        // For M6, .pass is only legal during draw with an empty deck.
        guard case .draw = state.phase else {
            throw RulesError.illegalAction("pass outside draw phase is not supported yet")
        }
        guard state.pendingDraws.contains(player) else {
            throw RulesError.illegalAction("\(player) is not pending a draw")
        }
        guard state.players[player]?.deck.isEmpty == true else {
            throw RulesError.illegalAction("cannot pass draw with a non-empty deck")
        }
        var newState = state
        newState.pendingDraws.remove(player)
        if newState.pendingDraws.isEmpty {
            newState = advanceToNextTurn(newState)
        }
        return newState
    }

    private static func advanceToNextTurn(_ state: GameState) -> GameState {
        var s = state
        // Turn 9 always terminates in scoring; we should never reach the draw
        // advance on T9. Defensive branch:
        if s.turn >= 9 {
            s.phase = .gameOver(winner: nil)
            return s
        }
        s.turn += 1
        s.phase = .placement
        return s
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
