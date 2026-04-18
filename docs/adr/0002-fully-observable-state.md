# ADR-0002 — Fully-observable `GameState` (no per-player hidden info)

- **Status**: accepted
- **Date**: M2
- **Related SPEC**: §5.4 Placement, §6.1 `Placement`

## Context

The real game has hidden information: during placement both players commit
cards face-down, and opponents' hands are hidden in the traditional sense.
We have to decide whether the engine state reflects this (per-player views)
or keeps a single god-view and lets callers enforce privacy.

The practical question: in `GameState.placements`, do we store the actual
cards or just "blue placed *something* in qin"?

## Decision

**Single god-view state.** `Placement` carries the concrete `Card`. Hands
and decks are per-player but visible to any caller. Engine does no masking.

Fairness in AI vs AI simulations is enforced at the `Arena` layer by
filtering `Rules.legalActions` to the acting player's own actions, not by
hiding state.

## Consequences

**Positive**

- The engine is simple, introspectable and deterministic. Tests can set up
  any situation directly without threading "fog of war" masks.
- `Rules.legalActions` doesn't need to know which player is "looking"; it
  returns actions whose `player` field identifies the owner. `Arena` splits
  them per agent.
- MCTS doesn't need an explicit determinization step to guess opponent hands
  — they're already resolved. This is why our "MCTS" (ADR-0010) is really a
  2-ply minimax with random rollouts and not a canonical determinized MCTS.

**Negative**

- Two practical leaks a UI must address:
  1. During placement the UI must *display* only the acting player's own
     placements, even though the state carries both.
  2. Opponents' hands must be hidden from the local player.
- The `HeuristicAgent` and `MCTSAgent` can technically "peek" at opponent
  placements during their own turn. In random-vs-heuristic and
  heuristic-vs-MCTS fuzz this is symmetric (both sides have the same
  access), but a proper human-facing game against the MCTS AI needs a
  privacy layer between the engine and the human player's view.

## Future work

If cheat-resistance becomes a concern (e.g. online play), introduce a
`PlayerView(GameState, Player)` projection that strips opponent-private
fields before handing to an agent.
