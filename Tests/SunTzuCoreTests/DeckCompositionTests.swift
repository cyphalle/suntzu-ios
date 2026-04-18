import XCTest
@testable import SunTzuCore

/// M1 — Deck composition and initial setup — SPEC §5.2, §12 M1.
final class DeckCompositionTests: XCTestCase {

    // MARK: - standardDeck

    func test_standardDeck_has20Cards() {
        XCTAssertEqual(GameSetup.standardDeck(owner: .blue).count, 20)
        XCTAssertEqual(GameSetup.standardDeck(owner: .red).count, 20)
    }

    func test_standardDeck_exactComposition() {
        let deck = GameSetup.standardDeck(owner: .blue)
        for n in 1...10 {
            XCTAssertEqual(deck.filter { $0.value == .numeric(n) }.count, 1,
                           "standard deck must contain exactly one numeric(\(n))")
        }
        XCTAssertEqual(deck.filter { $0.value == .bonus(1) }.count, 3, "three +1")
        XCTAssertEqual(deck.filter { $0.value == .bonus(2) }.count, 1, "one +2")
        XCTAssertEqual(deck.filter { $0.value == .bonus(3) }.count, 1, "one +3")
        XCTAssertEqual(deck.filter { $0.value == .malus }.count, 3, "three -1")
        XCTAssertEqual(deck.filter { $0.value == .plague }.count, 2, "two plagues")
        // All cards owned by requested player.
        XCTAssertTrue(deck.allSatisfy { $0.owner == .blue })
    }

    // MARK: - beginnerDeck

    func test_beginnerDeck_has18Cards() {
        XCTAssertEqual(GameSetup.beginnerDeck(owner: .blue).count, 18)
        XCTAssertEqual(GameSetup.beginnerDeck(owner: .red).count, 18)
    }

    func test_beginnerDeck_noPlus2orPlus3() {
        let deck = GameSetup.beginnerDeck(owner: .red)
        XCTAssertEqual(deck.filter { $0.value == .bonus(2) }.count, 0)
        XCTAssertEqual(deck.filter { $0.value == .bonus(3) }.count, 0)
        XCTAssertEqual(deck.filter { $0.value == .bonus(1) }.count, 3, "keep the three +1")
        // Sanity: numeric 1..10 still there.
        for n in 1...10 {
            XCTAssertEqual(deck.filter { $0.value == .numeric(n) }.count, 1)
        }
    }

    // MARK: - newGame

    func test_newGame_handIs10Cards() {
        let state = GameSetup.newGame(seed: 42)
        XCTAssertEqual(state.players[.blue]?.hand.count, 10)
        XCTAssertEqual(state.players[.red]?.hand.count, 10)
    }

    func test_newGame_handContainsAllPermanents() {
        let state = GameSetup.newGame(seed: 42)
        for player in [Player.blue, .red] {
            let hand = state.players[player]?.hand ?? []
            for n in 1...6 {
                XCTAssertTrue(
                    hand.contains { $0.value == .numeric(n) },
                    "\(player) hand should contain numeric(\(n))"
                )
            }
        }
    }

    func test_newGame_deckPlusHandMatchesDeckSize() {
        let std = GameSetup.newGame(seed: 42, beginner: false)
        for player in [Player.blue, .red] {
            let h = std.players[player]?.hand.count ?? 0
            let d = std.players[player]?.deck.count ?? 0
            XCTAssertEqual(h + d, 20, "standard: hand+deck == 20 for \(player)")
        }
        let beg = GameSetup.newGame(seed: 42, beginner: true)
        for player in [Player.blue, .red] {
            let h = beg.players[player]?.hand.count ?? 0
            let d = beg.players[player]?.deck.count ?? 0
            XCTAssertEqual(h + d, 18, "beginner: hand+deck == 18 for \(player)")
        }
    }

    func test_newGame_isDeterministic() {
        let s1 = GameSetup.newGame(seed: 42)
        let s2 = GameSetup.newGame(seed: 42)
        // Cards have fresh UUIDs on each call (SPEC §0: UUID OK for identity).
        // Compare by card VALUE sequence — that must match for determinism.
        for player in [Player.blue, .red] {
            let h1 = s1.players[player]?.hand.map(\.value) ?? []
            let h2 = s2.players[player]?.hand.map(\.value) ?? []
            XCTAssertEqual(h1, h2, "\(player) hand values must be identical for same seed")
            let d1 = s1.players[player]?.deck.map(\.value) ?? []
            let d2 = s2.players[player]?.deck.map(\.value) ?? []
            XCTAssertEqual(d1, d2, "\(player) deck values must be identical for same seed")
        }
        // Different seed → different hand order.
        let s3 = GameSetup.newGame(seed: 1337)
        let blueHand1 = s1.players[.blue]?.hand.map(\.value) ?? []
        let blueHand3 = s3.players[.blue]?.hand.map(\.value) ?? []
        XCTAssertNotEqual(blueHand1, blueHand3, "different seed should yield different shuffle")
    }

    // MARK: - reserve / cemetery bookkeeping

    func test_newGame_standardReserveAndCemetery() {
        let s = GameSetup.newGame(seed: 1, beginner: false)
        // Standard: 21 armies = 18 reserve + 3 cemetery.
        XCTAssertEqual(s.players[.blue]?.reserve, 18)
        XCTAssertEqual(s.players[.blue]?.cemetery, 3)
        XCTAssertEqual(s.players[.red]?.reserve, 18)
        XCTAssertEqual(s.players[.red]?.cemetery, 3)
    }

    func test_newGame_beginnerReserveAndCemetery() {
        let s = GameSetup.newGame(seed: 1, beginner: true)
        // Beginner: 21 armies = 21 reserve + 0 cemetery.
        XCTAssertEqual(s.players[.blue]?.reserve, 21)
        XCTAssertEqual(s.players[.blue]?.cemetery, 0)
    }
}
