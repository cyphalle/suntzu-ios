import XCTest
@testable import SunTzuCore

/// M9 — End-to-end game loop — SPEC §12 M9.
final class FullGameTests: XCTestCase {

    /// Drive a full 9-turn game via uniformly random legal actions and verify
    /// the loop terminates in `gameOver`.
    func test_fullScriptedGame_9turns_terminatesInGameOver() throws {
        var rng = SeededRNG(seed: 42)
        var state = GameSetup.newGame(seed: 42)

        let maxSteps = 2000
        var step = 0
        while !Rules.isTerminal(state) && step < maxSteps {
            let actions = Rules.legalActions(in: state)
            if actions.isEmpty {
                XCTFail("no legal actions at step \(step), phase \(state.phase)")
                return
            }
            let idx = Int(rng.next() % UInt64(actions.count))
            state = try Rules.apply(actions[idx], to: state)
            step += 1
        }

        XCTAssertTrue(Rules.isTerminal(state), "game must terminate")
        XCTAssertLessThan(step, maxSteps, "game overran the safety limit")

        // Terminal state properties.
        if case .gameOver = state.phase {
            // ok
        } else {
            XCTFail("phase should be .gameOver, got \(state.phase)")
        }
        XCTAssertLessThanOrEqual(state.turn, 9)
    }

    /// Same fuzz but with the event-card variant enabled — game still terminates.
    func test_fullScriptedGame_withEvents_terminatesInGameOver() throws {
        var rng = SeededRNG(seed: 7)
        var state = GameSetup.newGame(seed: 7, events: true)

        let maxSteps = 2000
        var step = 0
        while !Rules.isTerminal(state) && step < maxSteps {
            let actions = Rules.legalActions(in: state)
            if actions.isEmpty {
                XCTFail("no legal actions at step \(step), phase \(state.phase)")
                return
            }
            let idx = Int(rng.next() % UInt64(actions.count))
            state = try Rules.apply(actions[idx], to: state)
            step += 1
        }

        XCTAssertTrue(Rules.isTerminal(state))
        XCTAssertLessThan(step, maxSteps)
    }
}
