import XCTest
@testable import SunTzuCore

/// M0 smoke: package compiles and types are accessible.
/// Real tests start in M1 (DeckCompositionTests) — SPEC §12.
final class ScaffoldSmokeTests: XCTestCase {
    func test_newGame_compiles() {
        let state = GameSetup.newGame(seed: 42)
        XCTAssertEqual(state.turn, 1)
        XCTAssertEqual(state.phase, .placement)
    }

    func test_seededRNG_isDeterministic() {
        var a = SeededRNG(seed: 123)
        var b = SeededRNG(seed: 123)
        XCTAssertEqual(a.next(), b.next())
    }
}
