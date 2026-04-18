# ADR-0011 — iOS app architecture (SwiftUI + SpriteKit + XcodeGen)

- **Status**: accepted
- **Date**: M13 (first pass)
- **Related SPEC**: §11 UI phase

## Context

The M13 deliverable is a playable iOS app that drives `SunTzuCore` against
the MCTS AI. Several choices need to be locked down early so the app
grows cleanly.

## Decision

### 1. SwiftUI hull around a SpriteKit board

The menu, top bar, hand, phase controls and game-over screens are pure
SwiftUI. The board itself is a single `SpriteView` hosting a
`BoardScene: SKScene`. Rationale:

- SwiftUI buys us layout, accessibility, theming and transitions for free.
- SpriteKit is a better fit for the board because we want free positioning
  of province discs, adjacency lines, animations on army cube moves, and
  tap hit-testing via coordinates rather than a grid of buttons.

### 2. `GameStore` = `@Observable @MainActor final class`

`GameStore` owns the current `GameState`, the AI's `MCTSAgent`, and a
JSON-backed save slot. It exposes `submitHumanAction(_:)` and
`advanceAutomatic()` as `async` methods.

AI computation is pushed off-main with `Task.detached(priority:
.userInitiated)`, which captures `state` and `mcts` by value, returns the
chosen action and the mutated agent, then reassigns them on the main
actor. This:

- Keeps the UI responsive (the `isThinking` flag powers a spinner overlay).
- Preserves the seeded-RNG determinism (ADR-0004) because the entire
  RNG chain stays inside the captured `MCTSAgent`.
- Avoids a separate actor for the AI — the Task.detached boundary is
  enough.

### 3. Save/load via `Codable` JSON in `Documents/`

Because `GameState` is already `Codable` (ADR-0001), persistence is a
single `JSONEncoder().encode(state).write(to: ...)` per action. We
persist eagerly after every human or AI move rather than at strategic
checkpoints — recovery from a kill is always instant.

The save file lives at `Documents/suntzu-game.json`. The main menu
shows "Reprendre" when that file exists; "Nouvelle partie" deletes it
before creating a fresh game so we never accidentally resume a stale
save. Game-over returns to the menu after deleting the save.

### 4. Xcode project generated via XcodeGen, not committed

`iOSApp/project.yml` is the source of truth. `xcodegen generate`
produces `SunTzu.xcodeproj`, which is gitignored along with `.build/`
and `DerivedData/`. Rationale:

- Xcode project files produce unreadable diffs and merge conflicts
  constantly.
- A text config forces each build-setting change to pass through code
  review.
- Fresh clones run one command (`xcodegen generate`) to bootstrap.

### 5. V1 scope: no events, no strategy-card selection

The engine supports both, but:

- **Events** add a `charsDeGuerre` "pick a second strategy" flow
  (`pendingExtraStrategy`) and chain-reactions between events — both
  still open engine work.
- **Strategy cards** need a dedicated selection UI before turn 1 plus
  targeted-action UX for `moveArmy`, `removeArmy`, `reinforce`, etc.

V1 launches games with `events: false` and empty `strategyCards`. The
`Evaluator` and the MCTS agent already work well without them, and the
human's decision surface stays focused on placement + reveal + draw.

### 6. Canonical withdrawal auto-resolution (no human prompt yet)

Per ADR-0005, the engine auto-resolves multi-source withdrawals in
`Province.allCases` order. V1 UI inherits this. Adding a
`.awaitingWithdrawal` phase + UI is queued for a later iteration.

## Consequences

**Positive**

- Scaffold compiles cleanly against Swift 6 strict concurrency with
  explicit `nonisolated` only on Identifiable's `id`.
- Human players experience a simple, deterministic flow: pick card →
  pick province, reveal combats, draw.
- Save is robust — any hard kill loses at most the in-flight AI move.

**Negative**

- V1 gameplay is strictly less rich than the physical game (no
  strategies, no events).
- The board scene is minimal (coloured discs); there is no art pass
  yet. Every placed card is represented by a dot colour-coded per
  player; combat animations are placeholders.
- Signing is manual — users must pick a development team in Xcode
  after `xcodegen generate`, or edit `project.yml`.

## Follow-up work

Tracked in [status.md](../status.md) under "Known deferred work":

1. Explicit strategy-card selection flow + targeted-action UI.
2. Event-card variant enabled toggle + chain-reaction handling.
3. `.awaitingWithdrawal` phase + UI prompt for multi-source choices.
4. Art pass on the SpriteKit scene (textures, animations).
5. Hook `Info.plist` / signing into CI once a paid team is available.
