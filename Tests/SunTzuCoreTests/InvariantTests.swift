import XCTest
@testable import SunTzuCore

/// M9 — Global invariants enforced throughout random games — SPEC §8.3, §12 M9.
final class InvariantTests: XCTestCase {

    /// Runs 100 random games (seeds 1..100) and checks invariants after every action.
    /// Uses standard mode without events so no armies are destroyed → totals equal 18.
    func test_invariants_holdAcross100RandomGames() throws {
        for seed in 1...100 {
            var rng = SeededRNG(seed: UInt64(seed) &+ 0xABCDEF01)
            var state = GameSetup.newGame(seed: UInt64(seed))
            verifyInvariants(state, initial: 18, context: "seed=\(seed) step=0")

            let maxSteps = 2000
            var step = 0
            while !Rules.isTerminal(state) && step < maxSteps {
                let actions = Rules.legalActions(in: state)
                if actions.isEmpty {
                    XCTFail("seed=\(seed) step=\(step): no legal actions, phase=\(state.phase)")
                    break
                }
                let idx = Int(rng.next() % UInt64(actions.count))
                let action = actions[idx]
                do {
                    state = try Rules.apply(action, to: state)
                } catch {
                    XCTFail("seed=\(seed) step=\(step): apply \(action) threw \(error)")
                    break
                }
                step += 1
                verifyInvariants(state, initial: 18, context: "seed=\(seed) step=\(step)")
            }

            XCTAssertTrue(
                Rules.isTerminal(state),
                "seed=\(seed): game did not terminate within \(maxSteps) steps"
            )
            XCTAssertLessThan(step, maxSteps)
        }
    }

    // MARK: - helpers

    private func verifyInvariants(_ state: GameState, initial: Int, context: String) {
        // Per province.
        for province in Province.allCases {
            guard let pv = state.provinces[province] else {
                return XCTFail("\(context): missing province \(province)")
            }
            XCTAssertGreaterThanOrEqual(pv.armies, 0, "\(context): \(province) armies negative")
            if pv.controller == nil {
                XCTAssertEqual(pv.armies, 0, "\(context): \(province) no controller but \(pv.armies) armies")
            } else {
                XCTAssertGreaterThan(pv.armies, 0, "\(context): \(province) controller but 0 armies")
            }
        }

        // Per player army conservation (no event removals in this test).
        for player in [Player.blue, .red] {
            guard let ps = state.players[player] else {
                return XCTFail("\(context): missing player \(player)")
            }
            let plateau = state.provinces.values.reduce(0) { acc, pv in
                acc + (pv.controller == player ? pv.armies : 0)
            }
            let total = ps.reserve + ps.setAside + plateau
            XCTAssertEqual(
                total, initial,
                "\(context): \(player) total armies \(total), expected \(initial) (reserve=\(ps.reserve), setAside=\(ps.setAside), plateau=\(plateau))"
            )
            XCTAssertGreaterThanOrEqual(ps.reserve, 0, "\(context): \(player) reserve negative")
            XCTAssertGreaterThanOrEqual(ps.setAside, 0)
            XCTAssertLessThanOrEqual(ps.deck.count + ps.hand.count, 20, "\(context): \(player) deck+hand > 20")
        }

        // Peste counter.
        XCTAssertGreaterThanOrEqual(state.pestesPlayedTotal, 0)
        XCTAssertLessThanOrEqual(state.pestesPlayedTotal, 4, "\(context): pestesPlayedTotal > 4")

        // Placements during placement phase.
        if case .placement = state.phase {
            XCTAssertLessThanOrEqual(state.placements.count, 10, "\(context): placements > 10 during placement")
        }

        // Terminal phase consistency.
        if case .gameOver = state.phase {
            XCTAssertTrue(Rules.isTerminal(state))
        } else {
            XCTAssertFalse(Rules.isTerminal(state))
        }
    }
}
