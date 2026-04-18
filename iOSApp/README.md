# SunTzu iOS app

SwiftUI front-end for the `SunTzuCore` engine. The board is pure SwiftUI
with Kenney medieval CC0 art — no SpriteKit.

## Status

- Main menu on a wooden banner, "Nouvelle partie" / "Reprendre" buttons
- Pure-SwiftUI board: tiled parchment texture, five province
  structures, adjacency lines, unit sprites for committed armies
- Hand with wood-textured cards, **drag & drop** onto provinces OR
  classic **tap card → tap province**; drafts face-up above the disc
  with a yellow border
- **Valider** button commits the five drafts at once (disabled until
  `5 / 5`); tap a drafted province to retract
- Reveal: one-tap "Révéler le combat suivant"
- Draw phase: keep-top / keep-bottom card picker, or pass on empty deck
- Game-over screen with summary + return-to-menu
- Save/resume via a JSON snapshot in `Documents/suntzu-game.json`

Human plays **blue** against the **MCTS** agent playing red.

## Not yet wired

- Strategy-card selection (engine supports; UI launches with empty `strategyCards`)
- Event-card variant (engine supports; UI launches with `events: false`)
- Explicit withdrawal-source prompt (canonical auto-resolution — ADR-0005)
- `.useRenfort` button (engine wired, no UI entry yet)
- Custom app icon (empty placeholder silences Xcode)

## Layout

```
iOSApp/
├── project.yml                               # XcodeGen input
├── CREDITS.md                                # Kenney asset attribution
└── Sources/SunTzu/
    ├── App/
    │   └── SunTzuApp.swift                   # @main + RootView
    ├── ViewModels/
    │   └── GameStore.swift                   # @Observable, save/load, drafts, AI dispatch
    ├── Views/
    │   ├── MainMenuView.swift
    │   ├── GameView.swift
    │   ├── TopBarView.swift                  # turn, score track, per-player pools
    │   ├── BoardView.swift                   # SwiftUI board + ProvinceDiscView
    │   ├── HandView.swift                    # draggable cards
    │   ├── PhaseControlsView.swift           # Valider / Révéler / draw
    │   └── GameOverView.swift
    └── Assets.xcassets/                       # 14 Kenney imagesets (CC0)
```

## Generating the Xcode project

The `.xcodeproj` is gitignored and generated on demand from
`project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen   # if not installed
cd iOSApp
xcodegen generate
open SunTzu.xcodeproj
```

Xcode picks up `SunTzuCore` as a local Swift Package via
`packages.path: ..`. Build & run on a device or simulator.

After any change to the filesystem layout (added / removed files in
`Sources/`), re-run `xcodegen generate` before building.

## Signing

The `project.yml` leaves `DEVELOPMENT_TEAM` blank. First time you open the
project in Xcode, go to the target's **Signing & Capabilities** tab and
pick your personal team, or edit `project.yml` and re-run
`xcodegen generate`.

## MCTS budget

`GameStore` constructs the MCTS agent with `simulationsPerMove: 300`,
tuned for responsiveness on iPhone hardware. Move computation runs
off-main via `Task.detached`; the UI shows a "L'adversaire réfléchit…"
overlay (`GameStore.isThinking`) while MCTS evaluates.

## Links to the engine

- Entry points the UI calls: `GameSetup.newGame`, `Rules.apply`,
  `Rules.legalActions`, `Rules.isTerminal`, `Rules.winner`,
  `Arena.actionOwner`
- Agent: `MCTSAgent`

## Why no committed .xcodeproj?

Xcode projects produce unreadable diffs and constant merge conflicts.
Keeping `project.yml` as the source of truth and generating locally is
the standard modern-iOS pattern.
