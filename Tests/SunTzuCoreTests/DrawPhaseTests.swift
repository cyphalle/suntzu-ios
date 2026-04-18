import XCTest
@testable import SunTzuCore

/// M6 — Draw phase — SPEC §5.8, §12 M6.
final class DrawPhaseTests: XCTestCase {

    // MARK: - Step 1: permanents return, non-permanents discarded

    func test_draw_returnsPermanentsToHand() {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.hand = []
        s.players[.red]!.hand = []

        let bluePerms = [
            Card(owner: .blue, value: .numeric(1)),
            Card(owner: .blue, value: .numeric(6)),
        ]
        let blueNonPerm = Card(owner: .blue, value: .numeric(8))
        s.placements = [
            Placement(player: .blue, province: .qin, card: bluePerms[0]),
            Placement(player: .blue, province: .chu, card: bluePerms[1]),
            Placement(player: .blue, province: .wu, card: blueNonPerm),
        ]

        let s2 = Rules.enterDrawPhase(s)

        XCTAssertEqual(s2.players[.blue]!.hand.count, 2)
        XCTAssertTrue(s2.players[.blue]!.hand.contains { $0.id == bluePerms[0].id })
        XCTAssertTrue(s2.players[.blue]!.hand.contains { $0.id == bluePerms[1].id })
        XCTAssertFalse(s2.players[.blue]!.hand.contains { $0.id == blueNonPerm.id })
        XCTAssertTrue(s2.placements.isEmpty)
    }

    func test_draw_removesNonPermanents_fromPlay() {
        var s = GameSetup.newGame(seed: 1)
        let initialBlueDeckSize = s.players[.blue]!.deck.count
        let nonPerm = Card(owner: .blue, value: .malus)
        s.placements = [Placement(player: .blue, province: .wu, card: nonPerm)]

        let s2 = Rules.enterDrawPhase(s)

        XCTAssertFalse(s2.players[.blue]!.hand.contains { $0.id == nonPerm.id },
                       "non-permanent must not return to hand")
        XCTAssertEqual(s2.players[.blue]!.deck.count, initialBlueDeckSize,
                       "non-permanent is not returned to deck either — removed from play")
    }

    func test_draw_entryPopulatesPendingDraws() {
        var s = GameSetup.newGame(seed: 1)
        s.placements = []
        let s2 = Rules.enterDrawPhase(s)
        XCTAssertEqual(s2.phase, .draw)
        XCTAssertEqual(s2.pendingDraws, Set<Player>([.blue, .red]))
    }

    // MARK: - Step 2: pickDrawCard mechanics

    func test_pickDrawCard_keepTop_bottomsOther() throws {
        var s = draftDrawState()
        let top = s.players[.blue]!.deck[0]
        let second = s.players[.blue]!.deck[1]
        let initialHandCount = s.players[.blue]!.hand.count
        let initialDeckCount = s.players[.blue]!.deck.count

        let s2 = try Rules.apply(
            .pickDrawCard(player: .blue, keep: top, bottom: second),
            to: s
        )

        XCTAssertEqual(s2.players[.blue]!.hand.count, initialHandCount + 1)
        XCTAssertTrue(s2.players[.blue]!.hand.contains { $0.id == top.id })
        XCTAssertEqual(s2.players[.blue]!.deck.count, initialDeckCount - 1,
                       "net −1 on deck: removed 2 from top, pushed 1 to bottom")
        // The bottom card should now be at the tail.
        XCTAssertEqual(s2.players[.blue]!.deck.last?.id, second.id)
        XCTAssertFalse(s2.pendingDraws.contains(.blue))
        XCTAssertTrue(s2.pendingDraws.contains(.red))
    }

    func test_pickDrawCard_withOneCardDeck_takesItDirectly() throws {
        var s = draftDrawState()
        // Truncate Blue's deck to exactly one card.
        s.players[.blue]!.deck = [Card(owner: .blue, value: .malus)]
        let only = s.players[.blue]!.deck[0]
        let initialHandCount = s.players[.blue]!.hand.count

        let s2 = try Rules.apply(
            .pickDrawCard(player: .blue, keep: only, bottom: nil),
            to: s
        )

        XCTAssertEqual(s2.players[.blue]!.hand.count, initialHandCount + 1)
        XCTAssertTrue(s2.players[.blue]!.deck.isEmpty)
    }

    func test_pickDrawCard_emptyDeck_requiresPass() throws {
        var s = draftDrawState()
        s.players[.blue]!.deck = []

        // pickDrawCard must be rejected on an empty deck.
        let anyCard = Card(owner: .blue, value: .numeric(1))
        XCTAssertThrowsError(
            try Rules.apply(
                .pickDrawCard(player: .blue, keep: anyCard, bottom: nil),
                to: s
            )
        )

        // .pass is the legal way to skip an empty-deck draw.
        let s2 = try Rules.apply(.pass(player: .blue), to: s)
        XCTAssertFalse(s2.pendingDraws.contains(.blue))
    }

    // MARK: - Turn advancement

    func test_bothPlayersDraw_thenAdvanceToNextTurnPlacement() throws {
        var s = draftDrawState()
        let blueTop = s.players[.blue]!.deck[0]
        let blueSecond = s.players[.blue]!.deck[1]
        let redTop = s.players[.red]!.deck[0]
        let redSecond = s.players[.red]!.deck[1]

        let turnBefore = s.turn
        s = try Rules.apply(.pickDrawCard(player: .blue, keep: blueTop, bottom: blueSecond), to: s)
        XCTAssertEqual(s.phase, .draw, "still waiting on red")

        s = try Rules.apply(.pickDrawCard(player: .red, keep: redTop, bottom: redSecond), to: s)
        XCTAssertEqual(s.turn, turnBefore + 1)
        XCTAssertEqual(s.phase, .placement)
        XCTAssertTrue(s.pendingDraws.isEmpty)
    }

    // MARK: - helpers

    /// State positioned at end-of-reveal on a non-scoring turn, ready for the draw phase.
    /// Populates placements with two permanents (so Step 1 is non-trivial) then enters draw.
    private func draftDrawState() -> GameState {
        var s = GameSetup.newGame(seed: 1)
        // Use turn 2 (not a scoring turn, so draw → turn 3 is a scoring turn start — but placement
        // of turn 3 happens normally, so we're still fine).
        s.turn = 1
        s.placements = []
        return Rules.enterDrawPhase(s)
    }
}
