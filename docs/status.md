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
| M13 | SwiftUI iOS app (SpriteKit retired, see ADR-0013) — main menu, pure-SwiftUI board, hand with drag & drop + tap-tap, draft/validate placement flow, reveal / draw controls, save & resume, MCTS AI wiring, full Kenney medieval art pass (ADR-0014) | — | 73 | 🟢 playable |
| Post-M13 | Randomised score displays + cemetery troop economy (ADR-0012), UI exposes reserve / cemetery / score displays / sixMarkers, Valider button, crash-safe illegal-action handling | covered by existing suite | 73 | ✅ |

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

## Known deferred work

### Engine (inside the core boundary)

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

### UI (iOS app)

- **Advanced mode** — strategy-card selection flow + event-card toggle.
  Engine supports both; the UI launches games with `events: false` and
  empty `strategyCards` (see [ADR-0011](adr/0011-ios-app-architecture.md)).
- **`.useRenfort` button** — engine wired, UI doesn't expose the
  "discard a non-permanent to recover a cube from the cemetery"
  action yet.
- **App icon** — placeholder `AppIcon.appiconset` (empty) silences the
  Xcode build error; a real icon hasn't been drawn yet.
- **Province selection at setup** — structure images (`province_qin` etc.)
  were chosen from thumbnails without playtest; swap the Kenney
  `Structure_XX` indices via Assets.xcassets once preferred ones surface.

None of these block gameplay. A full game against the MCTS AI is playable
end-to-end on iOS as of this snapshot.
