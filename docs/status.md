# Milestone status

Each row lists what was delivered, the test file it's gated behind, and the
cumulative test count after the milestone. See `SPEC.md` §12 for the original
plan and DoD.

| # | Milestone | Tests added | Cumulative | State |
|---|-----------|-------------|------------|-------|
| M0 | Scaffold SPM package, stubs, SeededRNG | 2 smoke | 2 | ✅ |
| M1 | Deck composition & initial setup (`standardDeck`, `beginnerDeck`, `newGame`) | `DeckCompositionTests` ×10 | 12 | ✅ |
| M2 | Placement phase (`.placeCard`, transition to reveal) | `PlacementPhaseTests` ×6 | 18 | ✅ |
| M3 | Combat basics: `effectiveValue`, `resolve`, Case A placement | `CombatTests` ×12 | 30 | ✅ |
| M4 | Combat cases B/C/D + `[WithdrawalSource]` plans + scripted turn 1 | `ArmyPlacementTests` ×7, `FullTurnTests` ×1 | 38 | ✅ |
| M5 | Scoring delta, clamp, victory (T3/T6/T9) | `ScoringTests` ×7 | 45 | ✅ |
| M6 | Draw phase: return permanents, `.pickDrawCard`, turn advance | `DrawPhaseTests` ×7 | 52 | ✅ |
| M7 | All 10 strategy cards (passive + active) | `StrategyCardTests` ×10 | 62 | ✅ |
| M8 | Event card variant (pandemie, charsDeGuerre, defi×2, infanterieLegere) | `EventCardTests` ×5 | 67 | ✅ |
| M9 | Full-loop fuzz + global invariants | `FullGameTests` ×2, `InvariantTests` ×1 (100 seeds) | 70 | ✅ |
| M10 | `RandomAgent` baseline + 1 000-game termination/balance test | `RandomAgentTests` ×1 | 71 | ✅ |
| M11 | `HeuristicAgent` + `Evaluator` + `Arena` + `GameAgent` protocol — beats Random ≥ 70 / 100 | `HeuristicAgentTests` ×1 | 72 | ✅ |
| M12 | `MCTSAgent` (2-ply minimax with blended random rollouts) — beats Heuristic ≥ 60 / 100 | `MCTSAgentTests` ×1 | 73 | ✅ |
| M13 | SwiftUI + SpriteKit iOS app | — | — | 🚧 |

## Determinism invariants

All tests seed their RNGs explicitly (`SeededRNG(seed:)`, `GameSetup.newGame(seed:)`)
so reruns are bit-exact. `Date()` is forbidden in the engine; `UUID()` is allowed
since card identity never affects game progression — the per-card sequence is
replayed from the seed.

## Test runtime budget

In release mode the full suite finishes under a minute:

- 72 engine + heuristic tests: ~0.7 s
- `RandomAgentTests` (1 000 games): ~1.3 s
- `MCTSAgentTests` (100 games, ~300 sims / move, 2-ply lookahead): ~3.5 min

The MCTS test is slow but self-contained; skip it with
`--skip MCTSAgentTests` for tight inner loops.

## Known deferred work (all inside the core boundary)

Cross-reference each with the relevant ADR for the "why".

- Explicit multi-source `specifyWithdrawal` pause/resume phase
  (auto-resolved canonically today — see [ADR-0005](adr/0005-auto-resolve-multi-source-withdrawals.md))
- Explicit visible `.scoring` phase pause
  (auto-applied today — see [ADR-0007](adr/0007-scoring-auto-applies-in-reveal.md))
- `pandemie` / `charsDeGuerre` chain-reaction when the newly-revealed event
  already meets its condition (single-event-per-reveal today)
- `pesteBottomDiscard` / `malusBottomDiscard` draw-time redirection
  (marked used today but no deck mutation)
- `pendingExtraStrategy` consumption action
  (flag is set by `charsDeGuerre` but no action to pick the 2nd strategy yet)
- Real `ScoreDisplay` values for the five provinces
  (stubbed to `(0, 0, 0)` — see [defaults.md](defaults.md) Q#4)

None of these block gameplay in the current fuzz / AI tests, but they need to
land before the UI milestone exposes them.
