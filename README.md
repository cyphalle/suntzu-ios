# Sun Tzu iOS

Native iOS implementation of *Sun Tzu* (Alan M. Newman / Asmodee–Nexus, 2008).
Personal, non-commercial project.

## Status

Core engine + three AI levels (random, heuristic, MCTS-style) complete —
**73 tests passing**, milestones M0 – M12 shipped. iOS app (M13) is
**playable** end-to-end against the MCTS AI: pure-SwiftUI board,
drag-drop + tap-tap placement with a draft/validate step, reveal/draw
controls, save & resume, full Kenney medieval art pass. Generate the
Xcode project with:

```sh
cd iOSApp && xcodegen generate && open SunTzu.xcodeproj
```

Deferred: strategy-card UI, event-card toggle, `.useRenfort` button,
custom app icon. See [`docs/status.md`](docs/status.md) for the full
deferred-work list.

## Stack

- Swift 6, iOS 17+
- Core engine: pure Swift Package (`SunTzuCore`), zero external deps, XCTest only
- UI (from M13): SwiftUI + SpriteKit
- Deterministic: xorshift64 seeded RNG, immutable value types

## Layout

```
Sources/SunTzuCore/
  Domain/                     # value types (Province, Card, GameState, Action, Phase, ...)
  Rules/                      # pure functions (Rules, Combat, ArmyPlacement, Scoring, EventTriggers)
  Setup/                      # newGame, deck builders
  AI/                         # GameAgent, Random / Heuristic / MCTS agents, Arena, Evaluator
  Util/                       # SeededRNG
Tests/SunTzuCoreTests/        # 73 XCTest cases
SPEC.md                       # implementation spec (source of truth)
docs/                         # project documentation (read this next)
```

## Build & test

```sh
swift build
swift test                    # full suite in debug
swift test -c release         # release build, recommended (esp. for MCTS)
```

## Documentation

- **[docs/README.md](docs/README.md)** — how the project is organised
- **[docs/status.md](docs/status.md)** — milestone tracker + test counts
- **[docs/defaults.md](docs/defaults.md)** — SPEC §13 open questions + what's been defaulted
- **[docs/adr/](docs/adr/)** — Architecture Decision Records (10 ADRs)
