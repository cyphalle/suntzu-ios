# ADR-0007 — Scoring auto-applies at end of reveal

- **Status**: accepted
- **Date**: M5
- **Related SPEC**: §5.3 turn structure, §5.7 scoring

## Context

SPEC §5.3 lists 5 turn phases including an explicit **décompte** (scoring)
on turns 3/6/9. Treating scoring as a user-visible phase means players see
the delta apply, watch the score track move, and acknowledge before the
draw phase starts. For a UI that's desirable.

For the engine we have the choice of:

1. Transition to a `.scoring` phase at end-of-reveal on T3/T6/T9, require
   an explicit action (`.pass` or similar) to advance, then enter draw or
   gameOver.
2. Treat scoring as the *edge* between reveal and draw — compute
   delta + victory inline when the reveal loop ends.

Option 1 doubles the state-machine complexity (extra phase, extra legal
action filtering, extra test paths) for a benefit that only materialises
in the UI.

## Decision

**Option 2.** `Rules.applyRevealNext` detects end-of-reveal on a scoring
turn and calls `Scoring.applyScoringAndCheckVictory` before moving to draw
or gameOver. The `.scoring` phase case remains in the `Phase` enum but is
not reachable from the current engine flow.

The scoring logic itself is still a separate, testable, pure unit
(`ScoringTests` covers it directly without going through `revealNext`).

## Consequences

**Positive**

- `Rules.legalActions` stays simple: placement → reveal → draw →
  placement or gameOver. No extra action just to "advance the score".
- `ScoringTests` test `computeDelta` and `applyScoringAndCheckVictory`
  directly; `FullGameTests` and `InvariantTests` exercise the integrated
  path.

**Negative**

- For M13 the UI will want to *pause on scoring* so the human sees the
  track advance. Two ways to reinstate:
  1. Have the ViewModel intercept `.draw` and first show a scoring
     animation, then call `.revealNext` (well, the draw continuation).
     Minimal engine change.
  2. Resurrect the `.scoring` phase and add a `.resolveScoring` action.
     Bigger change but cleaner semantic.
- Agents currently never see a `.scoring` phase, so adding one later is
  a non-breaking addition as long as they ignore unknown phases.
