# Architecture Decision Records

Durable record of engineering choices that weren't obvious from the spec alone.
Each ADR follows a short template: **Context → Decision → Consequences**.
Status is `accepted` unless an ADR supersedes it.

Numbering is append-only; if we revisit a decision we add a new ADR and mark
the old one `superseded by ADR-00XX`.

| # | Title | Status |
|---|-------|--------|
| [ADR-0001](0001-hexagonal-pure-functional-core.md) | Hexagonal pure-functional core engine | accepted |
| [ADR-0002](0002-fully-observable-state.md) | Fully-observable `GameState` (no per-player hidden info) | accepted |
| [ADR-0003](0003-zero-external-dependencies.md) | Zero external dependencies in the core | accepted |
| [ADR-0004](0004-deterministic-seeded-rng.md) | Deterministic seeded RNG, no `Date()` | accepted |
| [ADR-0005](0005-auto-resolve-multi-source-withdrawals.md) | Auto-resolve multi-source withdrawals canonically | accepted |
| [ADR-0006](0006-cap-combat-delta-to-available-armies.md) | Cap combat delta to available armies | accepted |
| [ADR-0007](0007-scoring-auto-applies-in-reveal.md) | Scoring auto-applies at end of reveal | accepted |
| [ADR-0008](0008-evaluator-fallback-bias.md) | Evaluator fallback bias for zeroed score displays | accepted |
| [ADR-0009](0009-arena-alternates-placement.md) | `Arena` alternates blue/red during placement | accepted |
| [ADR-0010](0010-mcts-as-2ply-with-rollouts.md) | "MCTS" implemented as 2-ply minimax + blended rollouts | accepted |
| [ADR-0011](0011-ios-app-architecture.md) | iOS app architecture (SwiftUI + SpriteKit + XcodeGen) | accepted |
| [ADR-0012](0012-troop-economy-cemetery.md) | Troop economy: 18/3 starting split, cemetery costs at reveal | accepted |
| [ADR-0013](0013-draft-validate-placement-ux.md) | Placement UX: local drafts + validate step | accepted |
| [ADR-0014](0014-kenney-asset-integration.md) | Kenney CC0 asset integration | accepted |
