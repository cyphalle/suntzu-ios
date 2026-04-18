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
            // Illegal input from the UI is a programming error; surface it.
            assertionFailure("illegal action \(action) in phase \(state.phase): \(error)")
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
