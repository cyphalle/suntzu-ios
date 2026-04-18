# ADR-0004 — Deterministic seeded RNG, no `Date()`

- **Status**: accepted
- **Date**: M0
- **Related SPEC**: §0 consignes (point 7), §6.3

## Context

Three consumers need repeatability:
1. `XCTest` — a failed assertion on seed 42 must reproduce bit-exactly.
2. `InvariantTests` (100 seeds) — any regression must pinpoint the seed that
   broke the invariant.
3. MCTS — tree search prunes and reuses identical subtrees only if state
   hashes are stable.

Using `SystemRandomNumberGenerator` or `Date()` as an entropy source breaks
all three.

## Decision

- All randomness flows through a seeded `SeededRNG` (xorshift64, SPEC §6.3).
- `GameSetup.newGame(seed:)` deterministically builds the initial state.
- Agents (`RandomAgent`, `HeuristicAgent`, `MCTSAgent`) hold their own
  seeded RNG for tie-breaking and rollouts.
- `Date()` is **forbidden** in the core. `UUID()` is **allowed** for card
  identity because UUIDs never feed back into game logic — the sequence of
  card *values* is replayed from the seed, which is what matters.

## Consequences

**Positive**

- Test failures reduce to "seed X, step Y" — no flaky reruns.
- MCTS can in principle use state hashes as keys (we don't today, but the
  option is preserved).
- Replays and save/load (`Codable` on `GameState`) are exact.

**Negative**

- Every agent carries RNG state that advances on every `choose` call.
  Encoded as `mutating func` in `GameAgent`, propagated via `inout` in
  `Arena`. Callers must respect this — passing `var` by copy would lose the
  RNG update.
- Re-running a game with the "same seed" but after a refactor that adds a
  new `rng.next()` call somewhere silently shifts the game into a different
  trajectory. We don't have a CI check for "seed-stability across commits";
  it's a known gap but not load-bearing for the current tests.

## Implementation note

`Util/SeededRNG.swift` reseeds `0` → `0xDEADBEEF` so no caller can
accidentally initialise a "null" RNG that outputs zero forever.
