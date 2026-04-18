import XCTest
@testable import SunTzuCore

/// M12 — MCTS beats heuristic on ≥ 60 of 100 seeded games — SPEC §12 M12.
final class MCTSAgentTests: XCTestCase {

    func test_mcts_beatsHeuristic_on60PlusOver100Games() throws {
        var mctsWins = 0
        var heuristicWins = 0
        var draws = 0

        for seed in UInt64(1)...UInt64(100) {
            var blue = MCTSAgent(
                player: .blue,
                seed: seed &+ 0x5151_5151,
                simulationsPerMove: 300,
                candidatePoolSize: 8
            )
            var red = HeuristicAgent(player: .red, seed: seed &+ 0x6262_6262)
            let state = try Arena.simulate(
                seed: seed,
                blueAgent: &blue,
                redAgent: &red
            )
            XCTAssertTrue(Rules.isTerminal(state), "seed=\(seed) did not terminate")
            switch Rules.winner(of: state) {
            case .blue: mctsWins += 1
            case .red:  heuristicWins += 1
            case nil:   draws += 1
            }
        }

        XCTAssertEqual(mctsWins + heuristicWins + draws, 100)
        XCTAssertGreaterThanOrEqual(
            mctsWins, 60,
            "MCTS (blue) won \(mctsWins)/100 vs Heuristic — red=\(heuristicWins), draws=\(draws)"
        )
    }
}
