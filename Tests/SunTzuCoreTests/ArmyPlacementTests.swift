import XCTest
@testable import SunTzuCore

/// M4 — Army placement cases B/C/D + withdrawal — SPEC §5.6.4, §5.6.5, §9.2, §9.4.
final class ArmyPlacementTests: XCTestCase {

    // MARK: - §9.2 — loser-controlled province

    /// Case B — n > delta: loser keeps province, loses `delta` armies to reserve.
    func test_case_B_loserKeepsProvince() throws {
        var s = makeBlueControlledWu(armies: 5, blueReserve: 10)
        s.players[.red]!.reserve = 15
        s = try runCombat(on: s, blue: .numeric(2), red: .numeric(5))

        XCTAssertEqual(s.provinces[.wu]?.controller, .blue)
        XCTAssertEqual(s.provinces[.wu]?.armies, 2)
        XCTAssertEqual(s.players[.blue]?.reserve, 10 + 3)
        XCTAssertEqual(s.players[.red]?.reserve, 15)
    }

    /// Case C — n == delta: province wiped, loser recovers n to reserve.
    func test_case_C_provinceWiped() throws {
        var s = makeBlueControlledWu(armies: 5, blueReserve: 10)
        s.players[.red]!.reserve = 15
        s = try runCombat(on: s, blue: .numeric(2), red: .numeric(7))

        XCTAssertNil(s.provinces[.wu]?.controller)
        XCTAssertEqual(s.provinces[.wu]?.armies, 0)
        XCTAssertEqual(s.players[.blue]?.reserve, 10 + 5)
        XCTAssertEqual(s.players[.red]?.reserve, 15)
    }

    /// Case D — n < delta: loser recovers n, winner takes province with (delta - n).
    func test_case_D_winnerTakesProvince() throws {
        var s = makeBlueControlledWu(armies: 5, blueReserve: 10)
        s.players[.red]!.reserve = 15
        s = try runCombat(on: s, blue: .numeric(2), red: .numeric(9))

        XCTAssertEqual(s.provinces[.wu]?.controller, .red)
        XCTAssertEqual(s.provinces[.wu]?.armies, 2)
        XCTAssertEqual(s.players[.blue]?.reserve, 10 + 5)
        XCTAssertEqual(s.players[.red]?.reserve, 13)
    }

    // MARK: - §9.4 — explicit withdrawal plan

    func test_withdrawal_fromReserveThenAdjacentProvinces() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.reserve = 1
        s.provinces[.chu] = ProvinceState(controller: .blue, armies: 3)
        s.provinces[.hanQi] = ProvinceState(controller: .blue, armies: 2)
        s.provinces[.wu] = ProvinceState()

        // Simulate Blue wins WU with delta=4 (blue numeric(5) vs red numeric(1)).
        let plan: [WithdrawalSource] = [
            .reserve(count: 1),
            .province(.chu, count: 2),
            .province(.hanQi, count: 1),
        ]
        let s2 = try ArmyPlacement.applyCombatDelta(
            to: s, province: .wu, winner: .blue, delta: 4, plan: plan
        )

        XCTAssertEqual(s2.provinces[.wu]?.controller, .blue)
        XCTAssertEqual(s2.provinces[.wu]?.armies, 4)
        XCTAssertEqual(s2.provinces[.chu]?.armies, 1)
        XCTAssertEqual(s2.provinces[.chu]?.controller, .blue)
        XCTAssertEqual(s2.provinces[.hanQi]?.armies, 1)
        XCTAssertEqual(s2.provinces[.hanQi]?.controller, .blue)
        XCTAssertEqual(s2.players[.blue]?.reserve, 0)
    }

    func test_withdrawal_emptiesSourceProvince_clearsController() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.reserve = 0
        s.provinces[.chu] = ProvinceState(controller: .blue, armies: 2)
        s.provinces[.wu] = ProvinceState()

        let plan: [WithdrawalSource] = [.province(.chu, count: 2)]
        let s2 = try ArmyPlacement.applyCombatDelta(
            to: s, province: .wu, winner: .blue, delta: 2, plan: plan
        )

        XCTAssertEqual(s2.provinces[.wu]?.armies, 2)
        XCTAssertEqual(s2.provinces[.chu]?.armies, 0)
        XCTAssertNil(s2.provinces[.chu]?.controller, "empty province must have no controller")
    }

    func test_withdrawal_rejects_planThatSumsWrong() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.reserve = 5
        let badPlan: [WithdrawalSource] = [.reserve(count: 2)]
        XCTAssertThrowsError(
            try ArmyPlacement.place(
                count: 4, player: .blue, into: .wu, state: s, plan: badPlan
            )
        ) { error in
            guard case RulesError.illegalAction = error else {
                return XCTFail("expected illegalAction, got \(error)")
            }
        }
    }

    func test_withdrawal_rejects_sourceNotControlled() throws {
        var s = GameSetup.newGame(seed: 1)
        s.players[.blue]!.reserve = 0
        s.provinces[.chu] = ProvinceState(controller: .red, armies: 3)

        let plan: [WithdrawalSource] = [.province(.chu, count: 2)]
        XCTAssertThrowsError(
            try ArmyPlacement.place(count: 2, player: .blue, into: .wu, state: s, plan: plan)
        )
    }

    // MARK: - helpers

    private func makeBlueControlledWu(armies: Int, blueReserve: Int) -> GameState {
        var s = GameSetup.newGame(seed: 1)
        s.provinces[.wu] = ProvinceState(controller: .blue, armies: armies)
        s.players[.blue]!.reserve = blueReserve
        return s
    }

    private func runCombat(on initial: GameState, blue: CardValue, red: CardValue) throws -> GameState {
        var s = initial
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
