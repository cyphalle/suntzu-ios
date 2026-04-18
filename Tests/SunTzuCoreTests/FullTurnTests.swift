import XCTest
@testable import SunTzuCore

/// M4 — scripted full turn 1 exercising placement + 5 reveals — SPEC §12 M4.
final class FullTurnTests: XCTestCase {

    func test_turn1_beginnerMode_completeTurn() throws {
        var s = GameSetup.newGame(seed: 42, beginner: true)

        // Hand-crafted placements. Override hands so the script is deterministic.
        let bluePlan: [(Province, CardValue)] = [
            (.qin, .numeric(2)),
            (.chu, .numeric(4)),
            (.jinYan, .numeric(7)),
            (.hanQi, .numeric(1)),
            (.wu, .numeric(5)),
        ]
        let redPlan: [(Province, CardValue)] = [
            (.qin, .numeric(5)),
            (.chu, .numeric(3)),
            (.jinYan, .numeric(6)),
            (.hanQi, .numeric(8)),
            (.wu, .numeric(2)),
        ]
        let blueCards = bluePlan.map { Card(owner: .blue, value: $0.1) }
        let redCards = redPlan.map { Card(owner: .red, value: $0.1) }
        s.players[.blue]!.hand = blueCards
        s.players[.red]!.hand = redCards

        for (i, (province, _)) in bluePlan.enumerated() {
            s = try Rules.apply(.placeCard(player: .blue, province: province, card: blueCards[i]), to: s)
        }
        for (i, (province, _)) in redPlan.enumerated() {
            s = try Rules.apply(.placeCard(player: .red, province: province, card: redCards[i]), to: s)
        }

        guard case .reveal(0, Province.turn1RevealOrder) = s.phase else {
            return XCTFail("expected reveal(0, turn1Order), got \(s.phase)")
        }

        for _ in 0..<5 {
            s = try Rules.apply(.revealNext, to: s)
        }

        // Expected per-province outcomes:
        // QIN: 2 vs 5 → Red wins +3 → Red 3
        // CHU: 4 vs 3 → Blue wins +1 → Blue 1
        // JIN-YAN: 7 vs 6 → Blue wins +1 → Blue 1
        // HAN-QI: 1 vs 8 → Red wins +7 → Red 7
        // WU: 5 vs 2 → Blue wins +3 → Blue 3
        XCTAssertEqual(s.provinces[.qin]?.controller, .red)
        XCTAssertEqual(s.provinces[.qin]?.armies, 3)
        XCTAssertEqual(s.provinces[.chu]?.controller, .blue)
        XCTAssertEqual(s.provinces[.chu]?.armies, 1)
        XCTAssertEqual(s.provinces[.jinYan]?.controller, .blue)
        XCTAssertEqual(s.provinces[.jinYan]?.armies, 1)
        XCTAssertEqual(s.provinces[.hanQi]?.controller, .red)
        XCTAssertEqual(s.provinces[.hanQi]?.armies, 7)
        XCTAssertEqual(s.provinces[.wu]?.controller, .blue)
        XCTAssertEqual(s.provinces[.wu]?.armies, 3)

        // Reserve bookkeeping — beginner starts at 21 reserve, 0 cemetery.
        // Blue placed 1 + 1 + 3 = 5 combat troops, played no 6 / +2 / +3 → 21 - 5 = 16, cemetery 0.
        // Red placed 3 + 7 = 10 combat troops, played a numeric(6) on jinYan → 1 cube to cemetery.
        // Red reserve = 21 - 10 - 1 = 10, cemetery = 1.
        XCTAssertEqual(s.players[.blue]?.reserve, 16)
        XCTAssertEqual(s.players[.blue]?.cemetery, 0)
        XCTAssertEqual(s.players[.red]?.reserve, 10)
        XCTAssertEqual(s.players[.red]?.cemetery, 1)

        // Turn 1 is not a scoring turn → end of reveal transitions to .draw,
        // which automatically processes placements (permanents return, others discarded).
        XCTAssertEqual(s.phase, .draw)

        // Blue placements: 2, 4, 7, 1, 5. Permanents (1..6): 2, 4, 1, 5 → 4 cards return.
        // Red placements: 5, 3, 6, 8, 2. Permanents (1..6): 5, 3, 6, 2 → 4 cards return.
        XCTAssertEqual(s.players[.blue]?.hand.count, 4)
        XCTAssertEqual(s.players[.red]?.hand.count, 4)

        // Placements are consumed on entering the draw phase.
        XCTAssertTrue(s.placements.isEmpty)
        XCTAssertEqual(s.pendingDraws, Set<Player>([.blue, .red]))
    }
}
