# ADR-0009 — `Arena` alternates blue / red during placement

- **Status**: accepted
- **Date**: M12
- **Related SPEC**: §5.4, §13 Q#6

## Context

During placement both players place 5 cards, "simultaneously" per the
rules. The engine accepts placements in any order as long as each player
ends up with 5 distinct provinces occupied — placement order doesn't
change game outcome because cards are face-down until reveal.

Originally the `Arena` simulator picked "any blue action first, any red
action second". In practice this meant **blue played all 5 placements
before red played any**. For random-vs-random (M10) and
heuristic-vs-random (M11) this was harmless because neither agent
leveraged the knowledge of earlier placements.

For M12, the MCTS agent models the opponent's response one ply ahead.
The reply model assumes that after *this* blue action, the **next move is
the opponent's reply**. With the old Arena, the next move was blue's own
second placement — opponent modelling was meaningless and MCTS lost
heavily to the heuristic.

## Decision

During the placement phase, `Arena.simulate` alternates based on
`state.placements` counts:

```swift
let bluePlaced = state.placements.filter { $0.player == .blue }.count
let redPlaced  = state.placements.filter { $0.player == .red  }.count
let blueTurn   = bluePlaced <= redPlaced && !blueActions.isEmpty
```

Blue → Red → Blue → Red → … until both hit 5 and the reveal phase starts.
Outside placement (reveal, draw), the previous "whoever has actions" logic
stays.

## Consequences

**Positive**

- MCTS's 2-ply lookahead is semantically accurate: after blue's candidate
  action, the immediate next legal action is a red reply.
- Heuristic-vs-random win rate is unchanged (alternation is symmetric —
  heuristic still chooses greedy regardless of order).
- The simulator is a more faithful approximation of the real
  simultaneous-reveal ritual.

**Negative**

- `Arena` now knows a tiny bit about the placement phase (counts from
  `state.placements`). Acceptable coupling — `Arena` is a test harness,
  not a rule.
- A human-facing iOS UI will likely enforce simultaneous placement by a
  different mechanism (e.g. both players commit before reveal). `Arena`'s
  alternation is a simulation convenience; UI won't reuse it.

## Cross-reference

ADR-0010 describes the MCTS agent that depends on this alternation.
