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
        case let .useStrategy(player, strategy, target):
            return try applyUseStrategy(player: player, strategy: strategy, target: target, state: state)
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
                    // Filter 6-in-already-marked-province: needs unused double6.
                    if case .numeric(6) = card.value,
                       state.provinces[province]?.sixMarkers.contains(player) == true {
                        let hasDouble6 = state.players[player]?.strategyCards.contains(.double6) == true
                        let usedDouble6 = state.players[player]?.usedStrategies.contains(.double6) == true
                        if !hasDouble6 || usedDouble6 { continue }
                    }
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

        // Track played-card counters before combat logic — SPEC §5.6.6.
        for placement in [blue, red] {
            switch placement.card.value {
            case .plague:
                newState.pestesPlayedTotal += 1
            case .numeric(6):
                if var ps = newState.players[placement.player] {
                    ps.sixesPlayed += 1
                    newState.players[placement.player] = ps
                }
                if var pv = newState.provinces[province] {
                    pv.sixMarkers.insert(placement.player)
                    newState.provinces[province] = pv
                }
            default:
                break
            }
        }

        let outcome = Combat.resolve(blue: blue.card, red: red.card, state: newState)
        switch outcome {
        case .tie:
            break
        case let .result(winner, delta):
            newState = try ArmyPlacement.applyCombatDelta(
                to: newState,
                province: province,
                winner: winner,
                delta: delta
            )
        case let .plague(_, pesteTotal):
            newState = applyPlague(
                province: province,
                pesteTotal: pesteTotal,
                state: newState
            )
        }

        // Post-combat event triggers — SPEC §5.10, §5.6.6.
        newState = try EventTriggers.applyPostCombatEvents(
            newState,
            bluePlacement: blue,
            redPlacement: red,
            outcome: outcome
        )

        // An event may have ended the game (5th event applied).
        if case .gameOver = newState.phase {
            return newState
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
        for player in [Player.blue, .red] where state.pendingDraws.contains(player) {
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

    // MARK: - Plague

    private static func applyPlague(
        province: Province,
        pesteTotal: Bool,
        state: GameState
    ) -> GameState {
        var s = state
        guard var pv = s.provinces[province], let controller = pv.controller else {
            return s
        }
        let armies = pv.armies
        let destroyed = pesteTotal ? max(armies - 1, 0) : armies / 2
        pv.armies -= destroyed
        if pv.armies == 0 { pv.controller = nil }
        s.provinces[province] = pv
        if var ps = s.players[controller] {
            ps.reserve += destroyed
            s.players[controller] = ps
        }
        return s
    }

    // MARK: - Strategies

    private static func applyUseStrategy(
        player: Player,
        strategy: StrategyCard,
        target: StrategyTarget?,
        state: GameState
    ) throws -> GameState {
        if case .gameOver = state.phase {
            throw RulesError.illegalAction("useStrategy after gameOver")
        }
        guard let ps = state.players[player] else {
            throw RulesError.malformedState("missing player \(player)")
        }
        guard ps.strategyCards.contains(strategy) else {
            throw RulesError.illegalAction("\(player) does not hold \(strategy)")
        }
        guard !ps.usedStrategies.contains(strategy) else {
            throw RulesError.illegalAction("\(strategy) already used by \(player)")
        }

        var newState = state

        switch strategy {
        case .startBonus:
            newState.scoreTrack += 1

        case .removeArmy:
            guard case let .province(province) = target else {
                throw RulesError.illegalAction("removeArmy requires a province target")
            }
            guard var pv = newState.provinces[province],
                  let owner = pv.controller,
                  pv.armies > 0 else {
                throw RulesError.illegalAction("\(province) has no armies to remove")
            }
            pv.armies -= 1
            if pv.armies == 0 { pv.controller = nil }
            newState.provinces[province] = pv
            if var op = newState.players[owner] {
                op.reserve += 1
                newState.players[owner] = op
            }

        case .reinforce:
            guard case let .province(province) = target else {
                throw RulesError.illegalAction("reinforce requires a province target")
            }
            guard var pp = newState.players[player], pp.reserve > 0 else {
                throw RulesError.illegalAction("\(player) has no reserve to reinforce")
            }
            guard var pv = newState.provinces[province], pv.controller == player else {
                throw RulesError.illegalAction("\(province) is not controlled by \(player)")
            }
            pp.reserve -= 1
            pv.armies += 1
            newState.players[player] = pp
            newState.provinces[province] = pv

        case .moveArmy:
            guard case let .move(from, to) = target else {
                throw RulesError.illegalAction("moveArmy requires a .move target")
            }
            guard Province.adjacency[from]?.contains(to) == true else {
                throw RulesError.illegalAction("\(to) is not adjacent to \(from)")
            }
            guard var src = newState.provinces[from],
                  src.controller == player,
                  src.armies > 0 else {
                throw RulesError.illegalAction("\(from) cannot source an army for \(player)")
            }
            guard var dst = newState.provinces[to] else {
                throw RulesError.malformedState("missing province \(to)")
            }
            guard dst.controller == nil || dst.controller == player else {
                throw RulesError.illegalAction("\(to) is controlled by the opponent")
            }
            src.armies -= 1
            if src.armies == 0 { src.controller = nil }
            dst.armies += 1
            dst.controller = player
            newState.provinces[from] = src
            newState.provinces[to] = dst

        case .double6,
             .pesteBottomDiscard,
             .malusBottomDiscard:
            // Mark used; effect hooks into placement / draw phases (double6 auto-
            // triggers in placeCard; discard-to-bottom wiring lands in later work).
            break

        case .pesteTotal, .pesteCounter, .count7to10As6:
            // Passive — normally no explicit action is required. Accepting the
            // call marks the strategy "used" but the passive effect stays via
            // strategyCards presence. SPEC §5.9.
            break
        }

        if var pp = newState.players[player] {
            pp.usedStrategies.insert(strategy)
            newState.players[player] = pp
        }
        return newState
    }

    // MARK: - Turn advance

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

        // SPEC §5.9 double6: a player cannot place a second 6 in a province where
        // they already placed one this game, unless they hold an unused double6
        // strategy, which is auto-consumed by the attempt.
        var doubleSixConsumed = false
        if case .numeric(6) = card.value,
           state.provinces[province]?.sixMarkers.contains(player) == true {
            let hasStrat = playerState.strategyCards.contains(.double6)
            let used = playerState.usedStrategies.contains(.double6)
            guard hasStrat, !used else {
                throw RulesError.illegalAction(
                    "\(player) already placed a 6 in \(province); needs double6"
                )
            }
            doubleSixConsumed = true
        }

        var newState = state
        playerState.hand.remove(at: idx)
        if doubleSixConsumed {
            playerState.usedStrategies.insert(.double6)
        }
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
