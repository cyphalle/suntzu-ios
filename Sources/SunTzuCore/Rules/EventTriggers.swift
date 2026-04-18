/// Event-card triggers evaluated after each combat resolution — SPEC §5.10, §5.6.6.
public enum EventTriggers {
    /// Inspect state after a resolved combat and, if the current `activeEvent`'s
    /// condition is now met, apply its effect and advance the event deck.
    /// Applying the 5th event ends the game immediately — SPEC §5.12.
    public static func applyPostCombatEvents(
        _ state: GameState,
        bluePlacement: Placement,
        redPlacement: Placement,
        outcome: CombatOutcome
    ) throws -> GameState {
        guard let event = state.activeEvent else { return state }
        guard conditionMet(
            event,
            state: state,
            blue: bluePlacement,
            red: redPlacement,
            outcome: outcome
        ) else { return state }

        var s = try applyEffect(
            event,
            state: state,
            blue: bluePlacement,
            red: redPlacement,
            outcome: outcome
        )
        s = advanceEventDeck(s)
        return s
    }

    // MARK: - conditions

    private static func conditionMet(
        _ event: EventCard,
        state: GameState,
        blue: Placement,
        red: Placement,
        outcome: CombatOutcome
    ) -> Bool {
        switch event {
        case .pandemie:
            return state.pestesPlayedTotal >= 4
        case .charsDeGuerre:
            let b = state.players[.blue]?.sixesPlayed ?? 0
            let r = state.players[.red]?.sixesPlayed ?? 0
            return (b >= 3 || r >= 3) && state.pendingExtraStrategy == nil
        case .defiChampion:
            return loserPlayed(.numeric(9), blue: blue, red: red, outcome: outcome)
        case .defiHero:
            return loserPlayed(.numeric(10), blue: blue, red: red, outcome: outcome)
        case .infanterieLegere:
            return blue.card.value == .numeric(1)
                && red.card.value == .numeric(1)
                && blue.province == red.province
        }
    }

    private static func loserPlayed(
        _ value: CardValue,
        blue: Placement,
        red: Placement,
        outcome: CombatOutcome
    ) -> Bool {
        guard case .result(let winner, _) = outcome else { return false }
        let loserPlacement = winner == .blue ? red : blue
        return loserPlacement.card.value == value
    }

    // MARK: - effects

    private static func applyEffect(
        _ event: EventCard,
        state: GameState,
        blue: Placement,
        red: Placement,
        outcome: CombatOutcome
    ) throws -> GameState {
        switch event {
        case .pandemie:
            var s = state
            s = removeOneArmy(from: .blue, in: s)
            s = removeOneArmy(from: .red, in: s)
            return s

        case .charsDeGuerre:
            var s = state
            let b = s.players[.blue]?.sixesPlayed ?? 0
            let r = s.players[.red]?.sixesPlayed ?? 0
            // In the rare case both hit the threshold on the same reveal,
            // the blue (first-in-order) holder wins the choice by default.
            s.pendingExtraStrategy = (b >= 3) ? .blue : (r >= 3 ? .red : nil)
            return s

        case .defiChampion:
            guard case .result(let winner, _) = outcome else { return state }
            return removeArmies(count: 1, from: winner.opponent, in: state)

        case .defiHero:
            guard case .result(let winner, _) = outcome else { return state }
            return removeArmies(count: 2, from: winner.opponent, in: state)

        case .infanterieLegere:
            let province = blue.province
            let behind: Player = state.scoreTrack > 0
                ? .red
                : (state.scoreTrack < 0 ? .blue : .blue)
            return try ArmyPlacement.applyCombatDelta(
                to: state,
                province: province,
                winner: behind,
                delta: 1
            )
        }
    }

    // MARK: - army removal (reserve → plateau) — SPEC §5.10 pandemie / §5.6.6 defi

    private static func removeArmies(count: Int, from player: Player, in state: GameState) -> GameState {
        var s = state
        for _ in 0..<count {
            s = removeOneArmy(from: player, in: s)
        }
        return s
    }

    private static func removeOneArmy(from player: Player, in state: GameState) -> GameState {
        var s = state
        if var ps = s.players[player], ps.reserve > 0 {
            ps.reserve -= 1
            s.players[player] = ps
            return s
        }
        for province in Province.allCases {
            guard var pv = s.provinces[province] else { continue }
            if pv.controller == player && pv.armies > 0 {
                pv.armies -= 1
                if pv.armies == 0 { pv.controller = nil }
                s.provinces[province] = pv
                return s
            }
        }
        return s
    }

    // MARK: - deck cycling

    private static func advanceEventDeck(_ state: GameState) -> GameState {
        var s = state
        if s.eventDeck.isEmpty {
            // Last event applied → SPEC §5.12.3 immediate game over.
            s.activeEvent = nil
            s.phase = .gameOver(winner: winnerByScoreTrack(s))
        } else {
            s.activeEvent = s.eventDeck.removeFirst()
        }
        return s
    }

    private static func winnerByScoreTrack(_ state: GameState) -> Player? {
        if state.scoreTrack > 0 { return .blue }
        if state.scoreTrack < 0 { return .red }
        return nil
    }
}
