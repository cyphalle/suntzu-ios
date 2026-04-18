import XCTest
@testable import SunTzuCore

/// M8 — Event-card variant (optional) — SPEC §5.10, §5.6.6, §12 M8.
final class EventCardTests: XCTestCase {

    /// `pandemie` — 4th plague globally → each player loses 1 army (reserve priority).
    func test_pandemie_triggersOnFourthPlague_removesOneArmyEachPlayer() throws {
        var s = GameSetup.newGame(seed: 1)
        s.activeEvent = .pandemie
        s.eventDeck = [.charsDeGuerre] // something after so game doesn't end
        s.pestesPlayedTotal = 3
        s.players[.blue]!.reserve = 5
        s.players[.red]!.reserve = 5
        s.provinces[.wu] = ProvinceState()

        let plague = Card(owner: .blue, value: .plague)
        let redNumber = Card(owner: .red, value: .numeric(5))
        s.placements = [
            Placement(player: .blue, province: .wu, card: plague),
            Placement(player: .red, province: .wu, card: redNumber),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        XCTAssertEqual(s2.pestesPlayedTotal, 4)
        XCTAssertEqual(s2.players[.blue]?.reserve, 4)
        XCTAssertEqual(s2.players[.red]?.reserve, 4)
        XCTAssertNotEqual(s2.activeEvent, .pandemie, "event must cycle after applying")
    }

    /// `charsDeGuerre` — 3rd 6 played by a player → that player is owed a 2nd strategy.
    func test_charsDeGuerre_triggersOnThirdSix_flagsExtraStrategy() throws {
        var s = GameSetup.newGame(seed: 1)
        s.activeEvent = .charsDeGuerre
        s.eventDeck = [.pandemie]
        s.players[.blue]!.sixesPlayed = 2 // next 6 takes it to 3
        s.provinces[.wu] = ProvinceState()

        let blueSix = Card(owner: .blue, value: .numeric(6))
        let redCard = Card(owner: .red, value: .numeric(1))
        s.placements = [
            Placement(player: .blue, province: .wu, card: blueSix),
            Placement(player: .red, province: .wu, card: redCard),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        XCTAssertEqual(s2.players[.blue]?.sixesPlayed, 3)
        XCTAssertEqual(s2.pendingExtraStrategy, .blue)
        XCTAssertNotEqual(s2.activeEvent, .charsDeGuerre)
    }

    /// `defiChampion` — a player plays a 9 and loses → loses 1 extra army.
    func test_defiChampion_removesOneArmyFromLoser() throws {
        var s = GameSetup.newGame(seed: 1)
        s.activeEvent = .defiChampion
        s.eventDeck = [.pandemie]
        s.players[.blue]!.reserve = 10
        s.players[.red]!.reserve = 10
        s.provinces[.wu] = ProvinceState()

        let blueNine = Card(owner: .blue, value: .numeric(9))
        let redTen = Card(owner: .red, value: .numeric(10))
        s.placements = [
            Placement(player: .blue, province: .wu, card: blueNine),
            Placement(player: .red, province: .wu, card: redTen),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        // Combat: Red wins delta 1 → WU Red 1, Red.reserve 9.
        XCTAssertEqual(s2.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 1)
        XCTAssertEqual(s2.players[.red]?.reserve, 9)
        // defiChampion: Blue loses 1 extra army from reserve.
        XCTAssertEqual(s2.players[.blue]?.reserve, 9)
    }

    /// `defiHero` — a player plays a 10 and loses → loses 2 extra armies.
    func test_defiHero_removesTwoArmiesFromLoser() throws {
        var s = GameSetup.newGame(seed: 1)
        s.activeEvent = .defiHero
        s.eventDeck = [.pandemie]
        s.players[.blue]!.reserve = 10
        s.players[.red]!.reserve = 10
        s.provinces[.wu] = ProvinceState()

        // Blue plays 10, Red plays bonus(+1): effBlue=10, effRed=10+1=11 → Red +1
        let blueTen = Card(owner: .blue, value: .numeric(10))
        let redBonus = Card(owner: .red, value: .bonus(1))
        s.placements = [
            Placement(player: .blue, province: .wu, card: blueTen),
            Placement(player: .red, province: .wu, card: redBonus),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        XCTAssertEqual(s2.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 1)
        XCTAssertEqual(s2.players[.red]?.reserve, 9) // -1 for combat
        XCTAssertEqual(s2.players[.blue]?.reserve, 8) // -2 for defiHero
    }

    /// `infanterieLegere` — both players place a 1 in the same province →
    /// the scoreTrack-behind player wins it with delta 1.
    func test_infanterieLegere_awardsProvinceToBehindPlayer() throws {
        var s = GameSetup.newGame(seed: 1)
        s.activeEvent = .infanterieLegere
        s.eventDeck = [.pandemie]
        s.scoreTrack = 2 // blue ahead → red is behind
        s.players[.blue]!.reserve = 10
        s.players[.red]!.reserve = 10
        s.provinces[.wu] = ProvinceState()

        let blueOne = Card(owner: .blue, value: .numeric(1))
        let redOne = Card(owner: .red, value: .numeric(1))
        s.placements = [
            Placement(player: .blue, province: .wu, card: blueOne),
            Placement(player: .red, province: .wu, card: redOne),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        XCTAssertEqual(s2.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 1)
        XCTAssertEqual(s2.players[.red]?.reserve, 9)
    }
}
