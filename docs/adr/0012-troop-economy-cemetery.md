# ADR-0012 — Troop economy: 18/3 starting split, cemetery costs at reveal

- **Status**: accepted
- **Date**: post-M13 revision
- **Related SPEC**: §5.1 constants, §5.6.6, §5.11, "gestion des troupes" user-supplied clarification

## Context

The original spec kept the "renfort exceptionnel" pool abstract — 3 cubes
starting aside in standard mode, discardable cards could recall one cube
into the reserve — but never wired the inverse direction: *when* does a
cube move INTO that pool?

User-supplied clarification landed the missing rule:

- Every player owns **21 cubes**, split **18 reserve + 3 cemetery** at
  start in standard mode.
- Playing a **+2** card sends **1 cube** to the cemetery at reveal.
- Playing a **+3** card sends **2 cubes** to the cemetery at reveal.
- Playing a **numeric(6)** on any province sends **1 cube** to the
  cemetery at reveal, on top of the existing sixMarker rule.
- Discarding a non-permanent card via `.useRenfort` pulls **1 cube**
  from the cemetery back to the reserve (pre-existing rule, now hooked
  up to the `.useRenfort` action).

## Decision

### Renamed pool

`PlayerState.setAside` → `PlayerState.cemetery`. The semantic is the
same pool; the new name matches the rulebook vocabulary ("cimetière")
and the mechanic now acts as a cost sink, not just a pre-game stash.

### Starting values

- **Standard**: `reserve = 18`, `cemetery = 3` (21 total).
- **Beginner**: `reserve = 21`, `cemetery = 0` (21 total, simplified).

### Cost timing: at reveal

Costs apply during `Rules.applyRevealNext`, immediately after the
sixMarker/plague counters update and before combat resolution. This
keeps placements face-down during the placement phase (no info leak
from watching a cube drop to the cemetery) and centralises the
bookkeeping.

### Cost source

`moveTroopsToCemetery(count:player:state:)` takes:

1. from **reserve** first,
2. fallback to any **controlled province** in `Province.allCases`
   order if the reserve runs out.

Empty pool everywhere ⇒ silent no-op (degenerate broke-player state).
Matches ADR-0006's army-conservation approach.

### Recall mechanism

`GameAction.useRenfort(player:, discarded:)` is now wired in
`Rules.apply`:

- discard must belong to the player
- discard must be non-permanent (fails on numeric 1..6)
- cemetery must have ≥ 1 cube
- moves one cube cemetery → reserve, removes the card from hand

### Score-display randomisation (bundled in same iteration)

`ScoreDisplay.random(using:)` samples three values in [1, 5] with sum
in [5, 10] via rejection sampling. `GameSetup.newGame` populates every
province with a fresh display, seeded. Resolves SPEC §13 Q#4.

### Evaluator retune

Real displays made the old `displayValue × 10 + 1` multiplier crush
everything else. Recalibrated to `× 3 + 1`, hand-strength weight
dropped from 0.15 → 0.05 (stopped the heuristic from hoarding good
cards), cemetery weight 1.0 → 0.3 (reflects it's locked until
discarded). Added a placement-commitment term that rewards committing
strong cards to valuable provinces — without it, 1-ply heuristic
placed its worst cards because placing a card only *lost* hand-strength
credit.

Benchmarks after retune (release build):

- HeuristicAgent vs RandomAgent: 7/100 → ≥ 70/100 (meets M11 target)
- MCTSAgent vs HeuristicAgent: ≥ 60/100 (meets M12 target)

## Consequences

**Positive**

- Starting army count now matches the rulebook (21), the cemetery is a
  real cost sink, and scoring actually produces non-zero deltas at
  T3/T6/T9, which makes strategy matter.
- `ADR-0008`'s fallback bias (`+1` per province) is no longer
  load-bearing; it still applies when a province happens to draw low
  values but isn't the dominant signal.

**Negative**

- Any previously-saved game JSON (pre-rename) breaks `Codable` because
  `setAside` → `cemetery`. Main menu's "Reprendre" silently drops
  stale saves. Acceptable since nothing ships yet.
- Beginner mode has no `+2`/`+3` in its deck, so the cost mechanic only
  triggers on 6s. Beginner's 0 starting cemetery means the first 6
  play grows the cemetery from 0, which is fine — just a minor
  inconsistency with "beginner = no cemetery mechanic".
