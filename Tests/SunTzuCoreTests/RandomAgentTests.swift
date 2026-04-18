import XCTest
@testable import SunTzuCore

/// M10 — Random baseline agent — SPEC §10.1, §12 M10.
final class RandomAgentTests: XCTestCase {

    /// 1000 random-vs-random games all terminate and the win split stays
    /// within ±10% of the 500/500 expectation.
    func test_randomVsRandom_1000games_terminateWithBalancedDistribution() {
        var blueWins = 0
        var redWins = 0
        var draws = 0
        var terminated = 0

        for seed in UInt64(1)...UInt64(1000) {
            var state = GameSetup.newGame(seed: seed)
            var agent = RandomAgent(seed: seed &+ 0xDEAD_BEEF)
            let maxSteps = 5000
            var step = 0
            while !Rules.isTerminal(state) && step < maxSteps {
                guard let action = agent.chooseAction(in: state) else { break }
                do {
                    state = try Rules.apply(action, to: state)
                } catch {
                    XCTFail("seed=\(seed) step=\(step): \(error)")
                    return
                }
                step += 1
            }
            guard Rules.isTerminal(state) else {
                XCTFail("seed=\(seed) did not terminate after \(step) steps, phase=\(state.phase)")
                return
            }
            terminated += 1
            switch Rules.winner(of: state) {
            case .blue: blueWins += 1
            case .red:  redWins += 1
            case nil:   draws += 1
            }
        }

        XCTAssertEqual(terminated, 1000)
        XCTAssertEqual(blueWins + redWins + draws, 1000)

        let diff = abs(blueWins - redWins)
        XCTAssertLessThan(
            diff, 100,
            "win split not within ±10% — blue=\(blueWins), red=\(redWins), draws=\(draws)"
        )
    }
}
