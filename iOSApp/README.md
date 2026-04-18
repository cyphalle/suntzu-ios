# SunTzu iOS app

SwiftUI + SpriteKit front-end for the `SunTzuCore` engine.

## Status (M13, first pass)

- Main menu with **New game** and **Resume** entries
- Full placement → reveal → scoring → draw → next turn loop
- Human plays **blue** against the MCTS agent playing **red**
- Save/resume via a JSON snapshot in `Documents/suntzu-game.json`
- Game-over screen with a turn summary and return-to-menu button

## Not yet wired

- Strategy-card selection UI (engine supports them, UI defers)
- Event-card variant (engine supports it, UI starts games with `events: false`)
- Explicit withdrawal-source choice (canonical auto-resolution by default — ADR-0005)
- Custom art / animations (scene uses coloured discs for provinces, discs only)

## Layout

```
iOSApp/
├── project.yml                              # XcodeGen input
└── Sources/SunTzu/
    ├── App/
    │   └── SunTzuApp.swift                  # @main + RootView
    ├── ViewModels/
    │   └── GameStore.swift                  # @Observable, save/load, AI dispatch
    ├── Views/
    │   ├── MainMenuView.swift
    │   ├── GameView.swift
    │   ├── TopBarView.swift
    │   ├── BoardView.swift                  # SwiftUI → SpriteView wrapper
    │   ├── HandView.swift
    │   ├── PhaseControlsView.swift
    │   └── GameOverView.swift
    └── Scene/
        ├── BoardScene.swift                 # SKScene + tap routing
        └── ProvinceNode.swift               # per-province token
```

## Generating the Xcode project

We don't commit the `.xcodeproj` — it's generated on demand from
`project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen   # if not installed
cd iOSApp
xcodegen generate
open SunTzu.xcodeproj
```

Once Xcode opens the project it picks up `SunTzuCore` as a local Swift
Package via `packages.path: ..`. Build & run on a device or simulator.

## Signing

The `project.yml` leaves `DEVELOPMENT_TEAM` blank. First time you open the
project in Xcode, go to the target's **Signing & Capabilities** tab and
pick your personal team, or edit `project.yml` and re-run
`xcodegen generate`.

## MCTS budget

`GameStore` constructs the MCTS agent with `simulationsPerMove: 300`,
tuned for responsiveness on real iPhone hardware. The move computation
runs off-main via `Task.detached`; the UI shows a short "thinking…"
overlay (`GameStore.isThinking`) while MCTS evaluates.

## Links to the engine

- Engine entry points the UI calls: `GameSetup.newGame`, `Rules.apply`,
  `Rules.legalActions`, `Rules.isTerminal`, `Rules.winner`, `Arena.actionOwner`
- Agent: `MCTSAgent`

## Why no committed .xcodeproj?

Xcode projects are near-impossible to review in git and auto-generate
diffs that don't survive a merge. Keeping `project.yml` as the source
of truth and generating locally is the same pattern used by most
modern iOS projects.
