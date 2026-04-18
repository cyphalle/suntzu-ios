# ADR-0006 — Cap combat delta to available armies

- **Status**: accepted
- **Date**: M9
- **Related SPEC**: §5.6.4 Cases A / D

## Context

`ArmyPlacement.applyCombatDelta` Case A says `province.armies += delta` and
calls `placeArmies(winner, delta, province)`. Case D similarly places
`delta - n` for the winner.

In pathological fuzz states (random agents throwing every card), a winner
might owe more armies than they have left: reserve 0, one other controlled
province with 2 armies, but `delta = 5`. The literal rule is "place 5
somehow" — there's no formal rule for what happens when the player is
effectively broke.

If we don't cap, two things break:
1. `ArmyPlacement.place` throws "insufficient armies" → fuzz deadlocks at
   M9.
2. Worse, if we silently debit what's available and still increment
   `province.armies` by the full delta, the army-conservation invariant
   `reserve + setAside + plateau == 18 (standard)` is violated.

## Decision

In the no-plan path, cap the committed delta to what the winner can
actually source:

```swift
let actual = plan != nil ? delta : min(delta, armiesAvailable(for: winner, excluding: province, in: state))
```

- **Case A**, `actual == 0` → no-op (province unchanged).
- **Case A**, `actual > 0` → increment province by `actual` and debit that
  exact amount.
- **Case D**, `actual == 0` → loser recovers `n` to reserve as specified,
  but the province wipes clean (controller = nil, armies = 0). Winner
  couldn't follow through.
- **Case D**, `actual > 0` → province becomes winner-controlled with
  `actual` armies.

When a caller passes an explicit `plan`, the cap is disabled — the plan is
assumed authoritative and the engine validates it instead.

## Consequences

**Positive**

- The army-conservation invariant is preserved unconditionally, which was
  critical for `InvariantTests` to pass on 100 seeds.
- Fuzz never deadlocks on a single action.
- Behaviour matches common sense: a broke winner can't teleport armies they
  don't have.

**Negative**

- Spec divergence: if the rulebook implicitly assumes the player always
  has enough armies at this point (which is plausible in balanced play),
  we're adding a branch the physical game never exercises. The cap's
  effects are silent — no event, no log. A UI designer who wants to
  surface "army exhausted" has to detect it externally.
- MCTS rollouts can produce capped outcomes, which can bias Evaluator
  signals when reserves are already depleted. Not observed to break
  anything but worth remembering during M11 / M12 tuning.
