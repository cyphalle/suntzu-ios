import Foundation
import Observation
import SunTzuCore

/// View-model for a single game session.
///
/// - Human plays `.blue`, the MCTS AI plays `.red`.
/// - Engine actions that do not require a human (`.revealNext`, AI moves,
///   and automatic AI-side draw picks) are performed automatically inside
///   `advanceAutomatic()`.
/// - State is persisted to `Documents/suntzu-game.json` after every action
///   so the session can be resumed from the main menu.
@MainActor
@Observable
final class GameStore {
    private(set) var state: GameState
    private var mcts: MCTSAgent

    /// Small UI flag so views can show a spinner while MCTS is thinking.
    private(set) var isThinking: Bool = false

    /// Local placement drafts — cards the human has queued onto provinces
    /// but has not yet committed to the engine. Cleared when the user
    /// validates or the placement phase ends.
    private(set) var humanDrafts: [Province: Card] = [:]

    static let humanPlayer: Player = .blue
    static let aiPlayer: Player = .red

    init(state: GameState, mctsSeed: UInt64) {
        self.state = state
        self.mcts = MCTSAgent(
            player: Self.aiPlayer,
            seed: mctsSeed,
            // Tuned for real-time play on iPhone — SPEC §10.3 budget target.
            simulationsPerMove: 300,
            maxRolloutSteps: 60,
            candidatePoolSize: 8
        )
    }

    // MARK: - Factories

    static func newGame(seed: UInt64 = .random(in: 1...UInt64.max)) -> GameStore {
        let state = GameSetup.newGame(seed: seed, beginner: false, events: false)
        deleteSave()
        let store = GameStore(state: state, mctsSeed: seed &+ 0xAAAA)
        store.persist()
        return store
    }

    static func resume() -> GameStore? {
        guard let loaded = try? loadFromDisk() else { return nil }
        return GameStore(state: loaded, mctsSeed: UInt64.random(in: 1...UInt64.max))
    }

    // MARK: - Human inputs

    /// Submit a human action and then let the engine catch up: auto-reveal,
    /// AI responses, AI-side draw picks, turn advances.
    func submitHumanAction(_ action: GameAction) async {
        applyChecked(action)
        await advanceAutomatic()
    }

    // MARK: - Drafts (placement preview)

    /// Cards currently in the hand that are not already earmarked for a province.
    var undraftedHand: [Card] {
        let drafted = Set(humanDrafts.values.map(\.id))
        return state.players[Self.humanPlayer]?.hand.filter { !drafted.contains($0.id) } ?? []
    }

    /// True when all 5 drafts are in and we're still in placement.
    var canValidate: Bool {
        if case .placement = state.phase {
            return humanDrafts.count == 5
        }
        return false
    }

    /// Queue `card` onto `province`. If the card was drafted elsewhere, move
    /// it. If another card was on the province, kick it back to the hand.
    func draft(card: Card, to province: Province) {
        guard case .placement = state.phase else { return }
        guard state.players[Self.humanPlayer]?.hand.contains(where: { $0.id == card.id }) == true else { return }
        // SixMarker gate — can't place a second 6 without double6 (engine
        // enforces this but the UI should avoid offering it).
        if case .numeric(6) = card.value,
           state.provinces[province]?.sixMarkers.contains(Self.humanPlayer) == true {
            let hasDouble6 = state.players[Self.humanPlayer]?.strategyCards.contains(.double6) == true
            let usedDouble6 = state.players[Self.humanPlayer]?.usedStrategies.contains(.double6) == true
            if !hasDouble6 || usedDouble6 { return }
        }
        // Remove the card from any previous draft province.
        for (p, c) in humanDrafts where c.id == card.id {
            humanDrafts.removeValue(forKey: p)
        }
        humanDrafts[province] = card
    }

    /// Remove whatever card is drafted on `province`.
    @discardableResult
    func clearDraft(at province: Province) -> Card? {
        return humanDrafts.removeValue(forKey: province)
    }

    /// Submit every drafted placement in sequence, then let the engine run
    /// AI replies and advance to the reveal phase.
    func validateDrafts() async {
        guard canValidate else { return }
        let snapshot = humanDrafts.sorted { a, b in
            provinceOrder(a.key) < provinceOrder(b.key)
        }
        humanDrafts.removeAll()
        for (province, card) in snapshot {
            applyChecked(.placeCard(
                player: Self.humanPlayer,
                province: province,
                card: card
            ))
        }
        await advanceAutomatic()
    }

    private func provinceOrder(_ province: Province) -> Int {
        switch province {
        case .qin: return 0
        case .chu: return 1
        case .jinYan: return 2
        case .hanQi: return 3
        case .wu: return 4
        }
    }

    // MARK: - Automatic advance

    /// Repeatedly apply engine-level and AI actions until either the game
    /// ends or a human decision is required.
    func advanceAutomatic() async {
        while !Rules.isTerminal(state) {
            let actions = Rules.legalActions(in: state)
            if actions.isEmpty { break }

            // Engine-level (revealNext) — autoplay.
            if let engineAction = actions.first(where: { Arena.actionOwner($0) == nil }) {
                applyChecked(engineAction)
                continue
            }

            // If any human action is legal, stop and wait for the user.
            if actions.contains(where: { Arena.actionOwner($0) == Self.humanPlayer }) {
                // Special case: during draw both players may act; let the AI
                // clear its own pick first before yielding.
                let aiActions = actions.filter { Arena.actionOwner($0) == Self.aiPlayer }
                if !aiActions.isEmpty && shouldAIDrawFirst() {
                    await applyAIMove(aiActions)
                    continue
                }
                return
            }

            // Only AI has legal actions → take one.
            let aiActions = actions.filter { Arena.actionOwner($0) == Self.aiPlayer }
            if aiActions.isEmpty { break }
            await applyAIMove(aiActions)
        }
        persist()
    }

    // MARK: - Internals

    private func shouldAIDrawFirst() -> Bool {
        // If we're in draw and the AI still owes a pick, resolve it so that
        // pending state is clean when the view renders.
        if case .draw = state.phase {
            return state.pendingDraws.contains(Self.aiPlayer)
        }
        return false
    }

    private func applyAIMove(_ actions: [GameAction]) async {
        isThinking = true
        defer { isThinking = false }
        let currentState = state
        let currentMCTS = mcts
        let (action, updatedMCTS) = await Task.detached(priority: .userInitiated) {
            () -> (GameAction, MCTSAgent) in
            var agent = currentMCTS
            let chosen = agent.choose(in: currentState, from: actions)
            return (chosen, agent)
        }.value
        mcts = updatedMCTS
        applyChecked(action)
    }

    private func applyChecked(_ action: GameAction) {
        do {
            state = try Rules.apply(action, to: state)
        } catch {
            // Illegal actions can surface from UI races (double-tap, stale
            // selection, reveal button pressed twice). The engine is the
            // source of truth; we swallow and log instead of crashing.
            #if DEBUG
            print("[GameStore] ignored illegal action: \(action) phase=\(state.phase) error=\(error)")
            #endif
        }
    }

    // MARK: - Persistence

    static func hasSave() -> Bool {
        FileManager.default.fileExists(atPath: saveURL().path)
    }

    static func deleteSave() {
        try? FileManager.default.removeItem(at: saveURL())
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: Self.saveURL(), options: .atomic)
    }

    private static func loadFromDisk() throws -> GameState {
        let data = try Data(contentsOf: saveURL())
        return try JSONDecoder().decode(GameState.self, from: data)
    }

    private static func saveURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("suntzu-game.json")
    }
}
