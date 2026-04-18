# ADR-0005 — Auto-resolve multi-source withdrawals canonically

- **Status**: accepted
- **Date**: M9
- **Related SPEC**: §5.6.5 (with the ⚠️ note on explicit choice)

## Context

When a winner's reserve is insufficient to back the delta, armies are pulled
from their controlled provinces. SPEC §5.6.5 lists the priority:

> 1. reserve
> 2. adjacent controlled province
> 3. any other controlled province

and adds:

> ⚠️ Quand plusieurs sources sont possibles (choix du joueur), cela doit être
> une action explicite `specifyWithdrawal` — pas un choix implicite du moteur.

Implementing the explicit choice requires a new **pending withdrawal phase**:
- `Rules.applyRevealNext` detects the shortfall
- Transitions to `.awaitingWithdrawal(player, province, remaining, ...)`
- `Rules.legalActions` emits `specifyWithdrawal(...)` options
- `Rules.apply(.specifyWithdrawal)` resolves and resumes the reveal loop

M9 needed 100 random-seed fuzz games to terminate. Without auto-resolution,
the random agent can't provide a `specifyWithdrawal` plan and fuzz deadlocks.

## Decision

The no-plan path of `ArmyPlacement.place` implements the spec's pseudo-
algorithm canonically (in `Province.allCases` order for adjacent then any
other). When a caller supplies an explicit `plan: [WithdrawalSource]`,
that plan is validated and used verbatim — the auto-path is bypassed.

Every call site that has a strategic interest in the choice (future UI,
stronger AI) can supply the plan; test fuzz and the current agents accept
the canonical outcome.

## Consequences

**Positive**

- Fuzz, full-game simulation and AI-vs-AI arenas all progress without user
  interaction.
- Spec compliance for the "single-source" case (reserve covers it) is
  exact.
- The canonical choice is deterministic across runs — it's just
  `Province.allCases.order`. Replays are stable.

**Negative**

- The ⚠️ ambiguity warning is **accepted**, not fixed. In the real game a
  player might prefer to empty a less-strategic province; we don't. The
  chosen province matters for later combats and scoring.
- For the iOS UI we will need the pending-withdrawal phase so the human
  can actually pick. M13 tracks this.

## Follow-up

Before M13 lands UI, introduce the `.awaitingWithdrawal` phase and
`specifyWithdrawal` action, keep the canonical auto-resolve as the AI
default (unchanged for tests), and have the UI prompt humans.
