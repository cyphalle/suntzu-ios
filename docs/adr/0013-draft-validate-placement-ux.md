# ADR-0013 — Placement UX: local drafts + validate step

- **Status**: accepted
- **Date**: post-M13 revision
- **Related SPEC**: §5.4 placement phase

## Context

The original iOS scaffold committed each human placement to the engine
the instant the user tapped a card and then a province. Feedback was
that this made the placement phase feel unforgiving:

1. No way to review before locking all five choices.
2. A misclick placed a card that could not be retrieved without a full
   engine action log.
3. Tap-tap was the only input method — no drag & drop.
4. The committed placement on a province was rendered as an anonymous
   dot, hiding the chosen card's value from the human who had just
   placed it.

## Decision

A **local draft layer** in `GameStore` separates the user's intent from
the engine's placement state, exposed through `humanDrafts: [Province:
Card]`. During the placement phase:

- `draft(card:to:)` adds or replaces a card on a province, returning
  a previously-drafted card to the hand automatically. Honours the
  `sixMarker` / `double6` gate so the UI never offers illegal plays.
- `clearDraft(at:)` retracts a placement (card goes back to hand).
- `canValidate` is true once all five drafts are in.
- `validateDrafts()` applies the five drafts to the engine in one shot
  and triggers the AI response via the existing `advanceAutomatic()`.

The SwiftUI board renders drafts face-up above the province disc
(yellow border, card value visible), while committed placements still
use face-down unit sprites. The **Valider** button in
`PhaseControlsView` is disabled until `5 / 5`. A live `N / 5` counter
tells the user where they are.

Input modalities live side-by-side:
- **Drag & drop** — `HandView` uses `.draggable(uuidString)` on each
  card and `BoardView` uses `.dropDestination(for: String.self)` on
  each province.
- **Tap-tap** — legacy flow preserved: select a card, tap a province.
- **Retract** — tap a drafted province with no card selected.

## Consequences

**Positive**

- The placement phase now matches the "commit when ready" feel of the
  physical game and gives humans the review moment they expected.
- The engine stays pure: draft state is UI-local, nothing about the
  rules engine changed. MCTS still sees the same stream of placements
  when they commit.
- Both input styles are supported without duplicating action logic.

**Negative**

- AI plays all five placements back-to-back after the user validates,
  then the reveal phase begins. ADR-0009's "alternate during
  placement" rhythm does not apply on the UI path — the user never
  watches the AI play mid-placement. That's a deliberate UX trade-off.
- One-way navigation: once validated, the user can't unroll the five
  placements. Matches the paper game; noted in case a future "undo"
  feature wants to revisit the decision.
