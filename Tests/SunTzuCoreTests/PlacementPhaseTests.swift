import XCTest
@testable import SunTzuCore

/// M2 — Placement phase — SPEC §5.4, §12 M2.
final class PlacementPhaseTests: XCTestCase {

    func test_legalActions_inPlacement_listsAllCardProvinceCombos() {
        let state = GameSetup.newGame(seed: 42)
        let actions = Rules.legalActions(in: state)

        // At T1 start: each player has 10 cards × 5 provinces = 50 placeCard options.
        // Both players active → 100 actions total.
        XCTAssertEqual(actions.count, 100)

        let blueCount = actions.filter {
            if case .placeCard(let p, _, _) = $0 { return p == .blue }
            return false
        }.count
        let redCount = actions.count - blueCount
        XCTAssertEqual(blueCount, 50)
        XCTAssertEqual(redCount, 50)

        // All listed cards must belong to the claimed player.
        for action in actions {
            if case .placeCard(let player, _, let card) = action {
                XCTAssertEqual(card.owner, player)
            }
        }
    }

    func test_placeCard_removesCardFromHand() throws {
        let s = GameSetup.newGame(seed: 42)
        let card = s.players[.blue]!.hand[0]
        let s2 = try Rules.apply(
            .placeCard(player: .blue, province: .qin, card: card),
            to: s
        )
        XCTAssertEqual(s2.players[.blue]!.hand.count, 9)
        XCTAssertFalse(s2.players[.blue]!.hand.contains { $0.id == card.id })
    }

    func test_placeCard_appendsToPlacements() throws {
        let s = GameSetup.newGame(seed: 42)
        let card = s.players[.blue]!.hand[0]
        let s2 = try Rules.apply(
            .placeCard(player: .blue, province: .qin, card: card),
            to: s
        )
        XCTAssertEqual(s2.placements.count, 1)
        XCTAssertEqual(s2.placements[0].player, .blue)
        XCTAssertEqual(s2.placements[0].province, .qin)
        XCTAssertEqual(s2.placements[0].card.id, card.id)
    }

    func test_placeCard_cannotPlaceTwiceInSameProvince() throws {
        let s = GameSetup.newGame(seed: 42)
        let hand = s.players[.blue]!.hand
        let s2 = try Rules.apply(
            .placeCard(player: .blue, province: .qin, card: hand[0]),
            to: s
        )
        XCTAssertThrowsError(
            try Rules.apply(
                .placeCard(player: .blue, province: .qin, card: hand[1]),
                to: s2
            )
        ) { error in
            guard case RulesError.illegalAction = error else {
                return XCTFail("expected illegalAction, got \(error)")
            }
        }
        // RED can still place in QIN — per-player restriction only.
        let redCard = s2.players[.red]!.hand[0]
        let s3 = try Rules.apply(
            .placeCard(player: .red, province: .qin, card: redCard),
            to: s2
        )
        XCTAssertEqual(s3.placements.count, 2)
    }

    func test_placeCard_cannotPlaceOpponentCard() {
        let s = GameSetup.newGame(seed: 42)
        let blueCard = s.players[.blue]!.hand[0]
        XCTAssertThrowsError(
            try Rules.apply(
                .placeCard(player: .red, province: .qin, card: blueCard),
                to: s
            )
        ) { error in
            guard case RulesError.illegalAction = error else {
                return XCTFail("expected illegalAction, got \(error)")
            }
        }
    }

    func test_transition_to_reveal_after_10_placements() throws {
        var s = GameSetup.newGame(seed: 42)
        for (i, province) in Province.turn1RevealOrder.enumerated() {
            let blueCard = s.players[.blue]!.hand[i]
            s = try Rules.apply(
                .placeCard(player: .blue, province: province, card: blueCard),
                to: s
            )
            let redCard = s.players[.red]!.hand[i]
            s = try Rules.apply(
                .placeCard(player: .red, province: province, card: redCard),
                to: s
            )
        }
        XCTAssertEqual(s.placements.count, 10)
        guard case .reveal(let nextIndex, let order) = s.phase else {
            return XCTFail("expected reveal phase, got \(s.phase)")
        }
        XCTAssertEqual(nextIndex, 0)
        XCTAssertEqual(order, Province.turn1RevealOrder)

        // Both hands should now have 5 cards left (started at 10, placed 5).
        XCTAssertEqual(s.players[.blue]!.hand.count, 5)
        XCTAssertEqual(s.players[.red]!.hand.count, 5)

        // No more placeCard actions available (phase changed).
        let actions = Rules.legalActions(in: s)
        XCTAssertTrue(actions.allSatisfy {
            if case .placeCard = $0 { return false }
            return true
        })
    }
}
