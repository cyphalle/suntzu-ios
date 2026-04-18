# SPEC §13 defaults — applied choices & validation TODOs

Every row in SPEC §13 is an ambiguity in the rulebook or a value we haven't
transcribed yet. We commit a default in code, grep-able via
`DEFAULT: see SPEC §13 Q#X`, and track validation here.

| Q# | Question | Status | Applied default | Where in code | Validation needed |
|----|----------|--------|-----------------|---------------|-------------------|
| Q#1 | Exact deck composition | ✅ RESOLVED | `{1..10}` + 3×+1 + 1×+2 + 1×+3 + 3×−1 + 2×P | `GameSetup.standardDeck` | — |
| Q#2 | Score-track size | ✅ RESOLVED | `scoreTrackMax = 9` | `Scoring.swift` | — |
| Q#3 | Province adjacency | ⚠️ DEFAULT | Risk-style graph (`qin ↔ jinYan, hanQi, chu` etc.) | `Province.adjacency` | Transcribe from the physical board before the UI milestone consumes it for `moveArmy` / withdrawal |
| Q#4 | Values of the ten score-display tokens | ✅ RESOLVED | Per-province random draw: three values in [1, 5] with sum ∈ [5, 10], seeded — `ScoreDisplay.random(using:)` | `GameSetup.newGame` via `ScoreDisplay.random` | — |
| Q#5 | Two simultaneous plagues | ⚠️ DEFAULT | The first-in-reveal-order (blue) plague resolves; the other is discarded silently | `Combat.resolve` | Confirm acceptable or supply the real tie-break |
| Q#6 | Placement order (simultaneous vs sequential) | ⚠️ DEFAULT | Treated as simultaneous: any order is legal; `Arena` alternates for AI fairness | `Rules.placementActions`, `Arena.simulate` | Accept or refine (e.g. strict privilege order) |
| Q#7 | `charsDeGuerre` pool for the 2nd strategy | ⚠️ DEFAULT | Pick from the four that were NOT chosen initially | Not yet enforced — only the `pendingExtraStrategy` flag is set | Design the pick action + confirm pool |

## Impact snapshot

- **Q#3 (adjacency)** — currently only affects `moveArmy` target validation and
  canonical withdrawal priority (ADR-0005). If real adjacency differs,
  `ArmyPlacement.place` picks slightly different sources, and `moveArmy`
  validates different targets. All rule-compliant; just different board
  geometry.
- **Q#4 (score displays)** — resolved via per-province rejection-sampled draws
  (three values in [1, 5], sum in [5, 10]). Seeded RNG shares the same
  sequence as deck shuffling, so `newGame(seed:)` remains bit-exact.
  `Evaluator` weights were retuned after resolving this (see
  [ADR-0008](adr/0008-evaluator-fallback-bias.md) and
  [ADR-0012](adr/0012-troop-economy-cemetery.md)).
- **Q#5 (two plagues)** — never observed in 100-seed fuzz; the default is a
  safe early-commit.
- **Q#6 (placement order)** — simultaneous treatment is strictly more
  permissive; any stricter rule is a subset. No rework expected when refined.
- **Q#7 (chars-de-guerre pool)** — consumption action doesn't exist yet, so
  the default is cheap to swap.

## Grep convention

Every applied default carries a comment of the form

```swift
// DEFAULT: see SPEC §13 Q#X — <one-line summary>
```

To audit before M13, run:

```sh
grep -rn "DEFAULT: see SPEC §13" Sources/
```
