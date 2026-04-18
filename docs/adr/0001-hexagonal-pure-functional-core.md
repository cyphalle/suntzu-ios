# ADR-0001 — Hexagonal pure-functional core engine

- **Status**: accepted
- **Date**: M0
- **Related SPEC**: §3 Architecture, §0 consignes

## Context

The project has a narrow, well-specified rule set (Sun Tzu board game) and a
broad frontier of potential consumers: XCTest fixtures, iOS UI, multiple AI
agents (random / heuristic / MCTS), and later possibly replays and remote
simulation for eval jobs. Every one of those consumers needs to share
**exactly** the same rule resolution, otherwise the AI trained on one
interpretation of the rules misbehaves against the engine the UI runs.

A classic mutable-object / "scene tree" architecture couples those consumers
to UI state. That's fine for a shipping game but terrible for testing edge
cases (combat cases B/C/D, plague interactions, event-card chain reactions).

## Decision

The engine is a **pure functional core**:

- Every domain type is a `struct` (`Codable + Hashable + Sendable`), never a
  `class`. Nothing is shared by reference.
- The rules layer is a namespace-only `enum` (`Rules`, `Combat`,
  `ArmyPlacement`, `Scoring`, `EventTriggers`) with **pure functions** of the
  form `(GameState, Action) -> GameState`.
- The only place mutation is allowed is the local scope of `inout` in a
  single function, and even there we return a fresh state at the boundary.
- No singletons, no shared caches, no globals.

Layering (see SPEC §3):

```
Domain  (no logic)
  ↑
Rules   (pure functions over Domain)
  ↑
Setup   (constructors of initial state)
  ↑
AI      (consumes Setup + Rules)
```

## Consequences

**Positive**

- Tests build state literally (`var s = GameSetup.newGame(...); s.placements = [...]`)
  without setup scaffolding — enabled `CombatTests`, `ArmyPlacementTests` and
  `ScoringTests` to stay short and local.
- `Rules.apply(action, to: state)` is trivially loggable, replayable, and
  hashable. `InvariantTests` leverages this: 100 seeded random games check
  invariants after every action.
- MCTS and heuristic agents rely on this — they clone state by value, apply
  candidate actions, evaluate, discard. No undo stack needed.
- Swift 6 strict concurrency is effectively free: `Sendable` is auto-derived
  for the whole graph.

**Negative**

- Every action allocates a fresh `GameState`. With ~20 stored fields and a
  dictionary or two, this is cheap, but not free. The 1 000-game random fuzz
  still finishes in ~1.3 s; the 100-game MCTS test relies on `-c release`
  optimisations to stay under the time budget.
- We can't "attach" runtime helpers (logger, telemetry) to the state object;
  they have to be passed explicitly. Accepted trade-off — the same
  constraint is what makes the core deterministic and replayable.
