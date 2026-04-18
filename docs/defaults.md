# SPEC §13 defaults — applied choices & validation TODOs

Every row in SPEC §13 is an ambiguity in the rulebook or a value we haven't
transcribed yet. We commit a default in code, grep-able via
`DEFAULT: see SPEC §13 Q#X`, and track validation here.

| Q# | Question | Status | Applied default | Where in code | Validation needed |
|----|----------|--------|-----------------|---------------|-------------------|
| Q#1 | Exact deck composition | ✅ RESOLVED | `{1..10}` + 3×+1 + 1×+2 + 1×+3 + 3×−1 + 2×P | `GameSetup.standardDeck` | — |
| Q#2 | Score-track size | ✅ RESOLVED | `scoreTrackMax = 9` | `Scoring.swift` | — |
| Q#3 | Province adjacency | ⚠️ DEFAULT | Risk-style graph (`qin ↔ jinYan, hanQi, chu` etc.) | `Province.adjacency` | Transcribe from the physical board before the UI milestone consumes it for `moveArmy` / withdrawal |
| Q#4 | Values of the ten score-display tokens | ⚠️ UNKNOWN | `ScoreDisplay(t3: 0, t6: 0, t9: 0)` stub for every province | `GameSetup.newGame` | Transcribe from the physical components — without real values scoring cannot produce a non-zero `scoreTrack`, which cascades into `Evaluator` biases |
| Q#5 | Two simultaneous plagues | ⚠️ DEFAULT | The first-in-reveal-order (blue) plague resolves; the other is discarded silently | `Combat.resolve` | Confirm acceptable or supply the real tie-break |
| Q#6 | Placement order (simultaneous vs sequential) | ⚠️ DEFAULT | Treated as simultaneous: any order is legal; `Arena` alternates for AI fairness | `Rules.placementActions`, `Arena.simulate` | Accept or refine (e.g. strict privilege order) |
| Q#7 | `charsDeGuerre` pool for the 2nd strategy | ⚠️ DEFAULT | Pick from the four that were NOT chosen initially | Not yet enforced — only the `pendingExtraStrategy` flag is set | Design the pick action + confirm pool |

## Impact snapshot

- **Q#3 (adjacency)** — currently only affects `moveArmy` target validation and
  canonical withdrawal priority (ADR-0005). If real adjacency differs,
  `ArmyPlacement.place` picks slightly different sources, and `moveArmy`
  validates different targets. All rule-compliant; just different board
  geometry.
- **Q#4 (score displays)** — the dominant unknown. With `(0, 0, 0)` stubs:
  - `Scoring.computeDelta` always returns `0`
  - games always end at T9 with tie-break by reserve
  - `Evaluator` falls back to a +1-per-controlled-province bias to still
    prefer winning combats
  - Real values will change AI balance and probably require re-tuning
    `Evaluator` weights (see [ADR-0008](adr/0008-evaluator-fallback-bias.md))
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
