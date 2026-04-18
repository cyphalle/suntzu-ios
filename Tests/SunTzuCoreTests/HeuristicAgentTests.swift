import XCTest
@testable import SunTzuCore

/// M11 — Heuristic agent beats Random on ≥ 70 of 100 seeded games — SPEC §12 M11.
final class HeuristicAgentTests: XCTestCase {

    func test_heuristic_beatsRandom_on70PlusOver100Games() throws {
        var heuristicWins = 0
        var randomWins = 0
        var draws = 0

        for seed in UInt64(1)...UInt64(100) {
            var blue = HeuristicAgent(player: .blue, seed: seed &+ 0xAAAA_1111)
            var red = RandomAgent(seed: seed &+ 0xBBBB_2222)
            let state = try Arena.simulate(
                seed: seed,
                blueAgent: &blue,
                redAgent: &red
            )
            XCTAssertTrue(Rules.isTerminal(state), "seed=\(seed) did not terminate")
            switch Rules.winner(of: state) {
            case .blue: heuristicWins += 1
            case .red:  randomWins += 1
            case nil:   draws += 1
            }
        }

        XCTAssertEqual(heuristicWins + randomWins + draws, 100)
        XCTAssertGreaterThanOrEqual(
            heuristicWins, 70,
            "Heuristic (blue) won \(heuristicWins)/100 vs Random — red=\(randomWins), draws=\(draws)"
        )
    }
}
