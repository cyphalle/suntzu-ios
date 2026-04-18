import XCTest
@testable import SunTzuCore

/// M5 — Scoring delta, clamping and victory — SPEC §5.7, §5.12, §9.5, §9.6.
final class ScoringTests: XCTestCase {

    func test_isScoringTurn() {
        XCTAssertTrue(Scoring.isScoringTurn(3))
        XCTAssertTrue(Scoring.isScoringTurn(6))
        XCTAssertTrue(Scoring.isScoringTurn(9))
        XCTAssertFalse(Scoring.isScoringTurn(1))
        XCTAssertFalse(Scoring.isScoringTurn(7))
    }

    /// §9.5 — Blue controls QIN/CHU/HAN-QI, Red controls WU, JIN-YAN empty.
    /// Delta = 7 − 3 = 4; scoreTrack 0 → 4, phase → draw (T3, not terminal).
    func test_scoring_turn3_computesDeltaAndAppliesClamped() {
        var s = makeState(turn: 3)
        s.provinces[.qin] = ProvinceState(controller: .blue, armies: 2)
        s.provinces[.chu] = ProvinceState(controller: .blue, armies: 2)
        s.provinces[.jinYan] = ProvinceState(controller: nil, armies: 0)
        s.provinces[.hanQi] = ProvinceState(controller: .blue, armies: 2)
        s.provinces[.wu] = ProvinceState(controller: .red, armies: 2)
        s.scoreDisplays = [
            .qin: ScoreDisplay(t3: 3, t6: 0, t9: 0),
            .chu: ScoreDisplay(t3: 2, t6: 0, t9: 0),
            .jinYan: ScoreDisplay(t3: 1, t6: 0, t9: 0),
            .hanQi: ScoreDisplay(t3: 2, t6: 0, t9: 0),
            .wu: ScoreDisplay(t3: 3, t6: 0, t9: 0),
        ]

        XCTAssertEqual(Scoring.computeDelta(s), 4)

        let s2 = Scoring.applyScoringAndCheckVictory(s)
        XCTAssertEqual(s2.scoreTrack, 4)
        XCTAssertEqual(s2.phase, .draw)
        XCTAssertFalse(Rules.isTerminal(s2))
    }

    /// §9.6 — Fin T6 with scoreTrack 7, +5 delta → clamped to 9, gameOver(blue).
    func test_earlyVictory_turn6_clampsScoreTrackAndEndsGame() {
        var s = makeState(turn: 6)
        s.scoreTrack = 7
        s.provinces[.qin] = ProvinceState(controller: .blue, armies: 2)
        s.provinces[.wu] = ProvinceState(controller: .blue, armies: 2)
        s.scoreDisplays = [
            .qin: ScoreDisplay(t3: 0, t6: 3, t9: 0),
            .wu: ScoreDisplay(t3: 0, t6: 2, t9: 0),
            .chu: ScoreDisplay(t3: 0, t6: 0, t9: 0),
            .jinYan: ScoreDisplay(t3: 0, t6: 0, t9: 0),
            .hanQi: ScoreDisplay(t3: 0, t6: 0, t9: 0),
        ]

        XCTAssertEqual(Scoring.computeDelta(s), 5)

        let s2 = Scoring.applyScoringAndCheckVictory(s)
        XCTAssertEqual(s2.scoreTrack, 9, "must clamp 12 down to +9")
        XCTAssertEqual(s2.phase, .gameOver(winner: .blue))
        XCTAssertTrue(Rules.isTerminal(s2))
        XCTAssertEqual(Rules.winner(of: s2), .blue)
    }

    /// Red can also hit -9 for a red win.
    func test_earlyVictory_turn3_redWinsAtMinus9() {
        var s = makeState(turn: 3)
        s.scoreTrack = -5
        s.provinces[.qin] = ProvinceState(controller: .red, armies: 2)
        s.provinces[.chu] = ProvinceState(controller: .red, armies: 2)
        s.scoreDisplays = [
            .qin: ScoreDisplay(t3: 3, t6: 0, t9: 0),
            .chu: ScoreDisplay(t3: 2, t6: 0, t9: 0),
            .jinYan: ScoreDisplay(t3: 0, t6: 0, t9: 0),
            .hanQi: ScoreDisplay(t3: 0, t6: 0, t9: 0),
            .wu: ScoreDisplay(t3: 0, t6: 0, t9: 0),
        ]

        let s2 = Scoring.applyScoringAndCheckVictory(s)
        XCTAssertEqual(s2.scoreTrack, -9) // clamped from -10
        XCTAssertEqual(s2.phase, .gameOver(winner: .red))
    }

    /// T9 always ends the game, even with small margin.
    func test_turn9_forcesGameOver_bySign() {
        var s = makeState(turn: 9)
        s.scoreTrack = 2
        // All t9 values 0 → no delta this turn.
        let s2 = Scoring.applyScoringAndCheckVictory(s)
        XCTAssertEqual(s2.scoreTrack, 2)
        XCTAssertEqual(s2.phase, .gameOver(winner: .blue))
    }

    /// T9 tiebreak by reserve count when scoreTrack == 0.
    func test_turn9_tiebreakByReserve_blueWins() {
        var s = makeState(turn: 9)
        s.scoreTrack = 0
        s.players[.blue]!.reserve = 5
        s.players[.red]!.reserve = 3
        let s2 = Scoring.applyScoringAndCheckVictory(s)
        XCTAssertEqual(s2.phase, .gameOver(winner: .blue))
    }

    /// Total tie (same reserves) → gameOver(winner: nil).
    func test_turn9_totalDraw() {
        var s = makeState(turn: 9)
        s.scoreTrack = 0
        s.players[.blue]!.reserve = 5
        s.players[.red]!.reserve = 5
        let s2 = Scoring.applyScoringAndCheckVictory(s)
        XCTAssertEqual(s2.phase, .gameOver(winner: nil))
        XCTAssertTrue(Rules.isTerminal(s2))
        XCTAssertNil(Rules.winner(of: s2))
    }

    // MARK: - helpers

    /// Fresh state with all-zero score displays and empty provinces.
    private func makeState(turn: Int) -> GameState {
        var s = GameSetup.newGame(seed: 1)
        s.turn = turn
        s.scoreDisplays = Dictionary(
            uniqueKeysWithValues: Province.allCases.map { ($0, ScoreDisplay(t3: 0, t6: 0, t9: 0)) }
        )
        s.provinces = Dictionary(
            uniqueKeysWithValues: Province.allCases.map { ($0, ProvinceState()) }
        )
        return s
    }
}
