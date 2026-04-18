# Documentation

Living documentation for the Sun Tzu iOS project.

## Contents

- **[status.md](status.md)** — milestone tracker (M0 – M13) and test counts
- **[defaults.md](defaults.md)** — SPEC §13 open questions, what was chosen and what still needs validation from the physical board
- **[adr/](adr/)** — Architecture Decision Records: durable, reviewable rationale for every non-obvious engineering choice

## How the project is organised

```
SunTzuCore package            — pure game engine (no UI, no I/O)
  Sources/SunTzuCore/
    Domain/                   — value types (Province, Card, GameState…)
    Rules/                    — pure functions: Rules, Combat, ArmyPlacement, Scoring, EventTriggers
    Setup/                    — newGame, deck builders
    AI/                       — GameAgent protocol, Random / Heuristic / MCTS agents, Arena, Evaluator
    Util/                     — SeededRNG
  Tests/SunTzuCoreTests/      — XCTest suite (73 tests as of M12)
SPEC.md                       — the source-of-truth spec this repo implements
docs/                         — this folder
```

## Running the suite

```sh
swift build
swift test                    # full suite (debug) — ~2 s except MCTS
swift test -c release         # release build, required to stay under the MCTS test's time budget
swift test --filter MCTSAgentTests -c release   # the slow one, ~3.5 min
```

## What is implemented

| Milestone | Scope | Status |
|-----------|-------|--------|
| M0 – M9   | Core game engine, deterministic, invariant-preserving (70 tests) | ✅ |
| M10       | Random baseline agent | ✅ |
| M11       | Heuristic agent (beats Random ≥ 70 / 100) | ✅ |
| M12       | MCTS-style agent (beats Heuristic ≥ 60 / 100) | ✅ |
| M13       | SwiftUI + SpriteKit iOS app | 🚧 pending |

See [status.md](status.md) for a milestone-by-milestone breakdown.
