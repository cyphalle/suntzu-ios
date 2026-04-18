import XCTest
@testable import SunTzuCore

/// M7 — Strategy cards — SPEC §5.9, §12 M7.
/// One test per strategy, verifying the primary effect.
final class StrategyCardTests: XCTestCase {

    // MARK: - RED strategies

    /// `double6` lets Red place a second 6 in a province already marked for Red.
    /// Auto-consumed during placement — no separate action.
    func test_double6_autoOverridesSixMarker_onPlacement() throws {
        var s = GameSetup.newGame(seed: 1)
        s.phase = .placement
        s.provinces[.qin]!.sixMarkers = [.red]
        s.players[.red]!.strategyCards = [.double6]
        let six = Card(owner: .red, value: .numeric(6))
        s.players[.red]!.hand = [six]

        let s2 = try Rules.apply(
            .placeCard(player: .red, province: .qin, card: six),
            to: s
        )
        XCTAssertEqual(s2.placements.count, 1)
        XCTAssertTrue(s2.players[.red]!.usedStrategies.contains(.double6))
    }

    /// `removeArmy` pulls 1 army off a province back to the owning player's reserve.
    func test_removeArmy_removesOneArmy_toOwnerReserve() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.red]!.strategyCards = [.removeArmy]
        s.provinces[.qin] = ProvinceState(controller: .blue, armies: 3)
        s.players[.blue]!.reserve = 10

        let s2 = try Rules.apply(
            .useStrategy(player: .red, strategy: .removeArmy, target: .province(.qin)),
            to: s
        )
        XCTAssertEqual(s2.provinces[.qin]?.armies, 2)
        XCTAssertEqual(s2.provinces[.qin]?.controller, .blue)
        XCTAssertEqual(s2.players[.blue]?.reserve, 11)
        XCTAssertTrue(s2.players[.red]!.usedStrategies.contains(.removeArmy))
    }

    /// `pesteTotal` changes plague effect from floor(armies/2) to all-but-one.
    func test_pesteTotal_destroysAllButOneArmy() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.red]!.strategyCards = [.pesteTotal]
        s.provinces[.wu] = ProvinceState(controller: .blue, armies: 6)
        s.players[.blue]!.reserve = 10

        let plague = Card(owner: .red, value: .plague)
        let blueCard = Card(owner: .blue, value: .numeric(5))
        s.placements = [
            Placement(player: .blue, province: .wu, card: blueCard),
            Placement(player: .red, province: .wu, card: plague),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 1)
        XCTAssertEqual(s2.provinces[.wu]?.controller, .blue)
        XCTAssertEqual(s2.players[.blue]?.reserve, 15)
        XCTAssertEqual(s2.pestesPlayedTotal, 1)
    }

    /// `pesteCounter` converts an opposing plague into effective 0 — normal combat.
    func test_pesteCounter_plagueCountsAsNumericZero() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.red]!.strategyCards = [.pesteCounter]

        let plague = Card(owner: .blue, value: .plague)
        let redCard = Card(owner: .red, value: .numeric(5))
        s.placements = [
            Placement(player: .blue, province: .wu, card: plague),
            Placement(player: .red, province: .wu, card: redCard),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        XCTAssertEqual(s2.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 5)
    }

    /// `pesteBottomDiscard` is marked used when explicitly activated.
    /// Actual deck redirection is wired in later milestones; SPEC §5.9.
    func test_pesteBottomDiscard_marksStrategyUsed() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.red]!.strategyCards = [.pesteBottomDiscard]

        let s2 = try Rules.apply(
            .useStrategy(player: .red, strategy: .pesteBottomDiscard, target: nil),
            to: s
        )
        XCTAssertTrue(s2.players[.red]!.usedStrategies.contains(.pesteBottomDiscard))
    }

    // MARK: - BLUE strategies

    /// `moveArmy` transfers 1 army between adjacent provinces (destination must be
    /// empty or player-controlled).
    func test_moveArmy_movesAcrossAdjacentProvinces() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.strategyCards = [.moveArmy]
        s.provinces[.chu] = ProvinceState(controller: .blue, armies: 3)
        s.provinces[.wu] = ProvinceState()

        let s2 = try Rules.apply(
            .useStrategy(player: .blue, strategy: .moveArmy, target: .move(from: .chu, to: .wu)),
            to: s
        )
        XCTAssertEqual(s2.provinces[.chu]?.armies, 2)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 1)
        XCTAssertEqual(s2.provinces[.wu]?.controller, .blue)
    }

    /// `count7to10As6` treats a 7/8/9/10 as a 6 for combat and does not mark the province.
    func test_count7to10As6_treatsHighNumericAsSix_noSixMarker() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.strategyCards = [.count7to10As6]

        let blueCard = Card(owner: .blue, value: .numeric(9))
        let redCard = Card(owner: .red, value: .numeric(3))
        s.placements = [
            Placement(player: .blue, province: .wu, card: blueCard),
            Placement(player: .red, province: .wu, card: redCard),
        ]
        s.phase = .reveal(nextIndex: 0, order: [.wu])

        let s2 = try Rules.apply(.revealNext, to: s)
        XCTAssertEqual(s2.provinces[.wu]?.controller, .blue)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 3, "9 counted as 6, delta = 6 - 3 = 3")
        XCTAssertFalse(s2.provinces[.wu]!.sixMarkers.contains(.blue))
    }

    /// `startBonus` pushes the scoreTrack one step toward Blue.
    func test_startBonus_incrementsScoreTrackTowardBlue() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.strategyCards = [.startBonus]
        XCTAssertEqual(s.scoreTrack, 0)

        let s2 = try Rules.apply(
            .useStrategy(player: .blue, strategy: .startBonus, target: nil),
            to: s
        )
        XCTAssertEqual(s2.scoreTrack, 1)
        XCTAssertTrue(s2.players[.blue]!.usedStrategies.contains(.startBonus))
    }

    /// `malusBottomDiscard` is marked used when explicitly activated. Full draw
    /// integration deferred — SPEC §5.9.
    func test_malusBottomDiscard_marksStrategyUsed() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.strategyCards = [.malusBottomDiscard]

        let s2 = try Rules.apply(
            .useStrategy(player: .blue, strategy: .malusBottomDiscard, target: nil),
            to: s
        )
        XCTAssertTrue(s2.players[.blue]!.usedStrategies.contains(.malusBottomDiscard))
    }

    /// `reinforce` takes 1 army from reserve into a player-controlled province.
    func test_reinforce_takesArmyFromReserve_intoControlledProvince() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.strategyCards = [.reinforce]
        s.players[.blue]!.reserve = 5
        s.provinces[.chu] = ProvinceState(controller: .blue, armies: 2)

        let s2 = try Rules.apply(
            .useStrategy(player: .blue, strategy: .reinforce, target: .province(.chu)),
            to: s
        )
        XCTAssertEqual(s2.players[.blue]?.reserve, 4)
        XCTAssertEqual(s2.provinces[.chu]?.armies, 3)
        XCTAssertTrue(s2.players[.blue]!.usedStrategies.contains(.reinforce))
    }
}
