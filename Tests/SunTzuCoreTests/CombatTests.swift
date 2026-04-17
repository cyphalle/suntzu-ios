import XCTest
@testable import SunTzuCore

/// M3 — Combat resolution (plague excluded, handled in M7) — SPEC §5.6, §9.1, §12 M3.
final class CombatTests: XCTestCase {

    // MARK: - effectiveValue (unit)

    func test_effectiveValue_numericVsAnything() {
        XCTAssertEqual(Combat.effectiveValue(own: .numeric(9), opp: .numeric(5)), 9)
        XCTAssertEqual(Combat.effectiveValue(own: .numeric(5), opp: .numeric(9)), 5)
        XCTAssertEqual(Combat.effectiveValue(own: .numeric(3), opp: .bonus(2)), 3)
    }

    func test_effectiveValue_bonusTable() {
        XCTAssertEqual(Combat.effectiveValue(own: .bonus(1), opp: .numeric(5)), 6)
        XCTAssertEqual(Combat.effectiveValue(own: .bonus(3), opp: .bonus(1)), 3)
        XCTAssertEqual(Combat.effectiveValue(own: .bonus(2), opp: .malus), 2)
    }

    func test_effectiveValue_malusTable() {
        XCTAssertEqual(Combat.effectiveValue(own: .malus, opp: .numeric(5)), 4)
        XCTAssertEqual(Combat.effectiveValue(own: .malus, opp: .bonus(2)), 0)
    }

    // MARK: - 9 combat cases from SPEC §9.1 (plague case 10 excluded)

    func test_case1_numeric9vs5_blueWinsDelta4_onEmptyWu() throws {
        let s = try runSingleCombat(blue: .numeric(9), red: .numeric(5))
        XCTAssertEqual(s.provinces[.wu]?.controller, .blue)
        XCTAssertEqual(s.provinces[.wu]?.armies, 4)
        XCTAssertEqual(s.players[.blue]?.reserve, 11)
        XCTAssertEqual(s.players[.red]?.reserve, 15)
    }

    func test_case2_numeric5vs5_tie() throws {
        let s = try runSingleCombat(blue: .numeric(5), red: .numeric(5))
        XCTAssertNil(s.provinces[.wu]?.controller)
        XCTAssertEqual(s.provinces[.wu]?.armies, 0)
        XCTAssertEqual(s.players[.blue]?.reserve, 15)
        XCTAssertEqual(s.players[.red]?.reserve, 15)
    }

    func test_case3_numeric3vs10_redWinsDelta7() throws {
        let s = try runSingleCombat(blue: .numeric(3), red: .numeric(10))
        XCTAssertEqual(s.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s.provinces[.wu]?.armies, 7)
        XCTAssertEqual(s.players[.red]?.reserve, 8)
        XCTAssertEqual(s.players[.blue]?.reserve, 15)
    }

    func test_case4_bonusPlus1vs5_blueWinsDelta1() throws {
        let s = try runSingleCombat(blue: .bonus(1), red: .numeric(5))
        XCTAssertEqual(s.provinces[.wu]?.controller, .blue)
        XCTAssertEqual(s.provinces[.wu]?.armies, 1)
        XCTAssertEqual(s.players[.blue]?.reserve, 14)
    }

    func test_case5_malusVs5_redWinsDelta1() throws {
        let s = try runSingleCombat(blue: .malus, red: .numeric(5))
        XCTAssertEqual(s.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s.provinces[.wu]?.armies, 1)
        XCTAssertEqual(s.players[.red]?.reserve, 14)
    }

    func test_case6_malusVsBonusPlus2_redWinsDelta2() throws {
        let s = try runSingleCombat(blue: .malus, red: .bonus(2))
        XCTAssertEqual(s.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s.provinces[.wu]?.armies, 2)
        XCTAssertEqual(s.players[.red]?.reserve, 13)
    }

    func test_case7_bonusPlus1VsBonusPlus3_redWinsDelta2() throws {
        let s = try runSingleCombat(blue: .bonus(1), red: .bonus(3))
        XCTAssertEqual(s.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s.provinces[.wu]?.armies, 2)
        XCTAssertEqual(s.players[.red]?.reserve, 13)
    }

    func test_case8_bonusPlus1VsBonusPlus1_tie() throws {
        let s = try runSingleCombat(blue: .bonus(1), red: .bonus(1))
        XCTAssertNil(s.provinces[.wu]?.controller)
        XCTAssertEqual(s.provinces[.wu]?.armies, 0)
        XCTAssertEqual(s.players[.blue]?.reserve, 15)
        XCTAssertEqual(s.players[.red]?.reserve, 15)
    }

    func test_case9_malusVsMalus_tie() throws {
        let s = try runSingleCombat(blue: .malus, red: .malus)
        XCTAssertNil(s.provinces[.wu]?.controller)
        XCTAssertEqual(s.provinces[.wu]?.armies, 0)
    }

    // MARK: - helpers

    /// Build a minimal state: both players place a single card on WU, reveal order = [WU].
    /// Bypasses the normal placement phase so tests can isolate combat logic.
    private func runSingleCombat(blue: CardValue, red: CardValue) throws -> GameState {
        var s = GameSetup.newGame(seed: 1)
        let blueCard = Card(owner: .blue, value: blue)
        let redCard = Card(owner: .red, value: red)
        s.placements = [
            Placement(player: .blue, province: .wu, card: blueCard),
            Placement(player: .red, province: .wu, card: redCard),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])
        return try Rules.apply(.revealNext, to: s)
    }
}
