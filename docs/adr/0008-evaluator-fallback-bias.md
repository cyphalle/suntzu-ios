# ADR-0008 — Evaluator fallback bias for zeroed score displays

- **Status**: accepted
- **Date**: M11
- **Related SPEC**: §13 Q#4, §10.2 heuristic

## Context

The AI `Evaluator` heavily weights **province control × score-display value
at the next scoring turn**. The score displays are currently stubbed to
`ScoreDisplay(t3: 0, t6: 0, t9: 0)` everywhere (SPEC §13 Q#4, unknown).

With a literal `displayValue × controlBonus`, the entire province term is
zero. The evaluator degenerates to "reserve + hand strength", which is a
bad heuristic: it rewards *not losing* over *winning*, leading to T9
tie-breaks by reserve, which produces many draws.

The M11 DoD requires the heuristic to beat random ≥ 70 / 100. With zero
provincial signal the heuristic beat random by a much smaller margin
(roughly 50 %).

## Decision

Add a small fixed **control bonus** on top of the scaled display value:

```swift
let controlValue = displayValue * 10 + 1
score += controlValue + Double(pv.armies) * 0.8   // controlled
score -= controlValue + Double(pv.armies) * 0.8   // opponent-controlled
```

So even when `displayValue == 0`, owning a province is worth `+1` vs
the opponent owning it (`-1`). Paired with the army buffer, it's just
enough bias to prefer winning combats.

The magnitude (`+1`) was tuned empirically: `+5` made the heuristic too
aggressive and flipped the MCTS-vs-heuristic gap in favour of the
heuristic (MCTS dropped to 26/100). `+1` keeps the overall balance and
the heuristic beats random as required, while MCTS beats heuristic.

## Consequences

**Positive**

- Heuristic meets M11 target (≥ 70/100 vs random).
- MCTS meets M12 target (≥ 60/100 vs heuristic) once paired with the
  2-ply lookahead (ADR-0010).
- Weight is easy to remove once real display values land (just set `+1`
  back to `0` or delete the constant).

**Negative**

- The fallback is **not in the rulebook** — it's an AI-only heuristic
  bias. Kept out of the engine itself and scoped strictly to `Evaluator`.
- When real values are transcribed, all AI tuning has to be revisited.
  `Evaluator`, `HeuristicAgent` and `MCTSAgent` constants should all be
  re-tested on the populated displays.

## Pointer

Marked inline in `Evaluator.swift` with a comment cross-referencing
[defaults.md Q#4](../defaults.md).
