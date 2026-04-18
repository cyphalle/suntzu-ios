# ADR-0010 — "MCTS" implemented as 2-ply minimax + blended rollouts

- **Status**: accepted
- **Date**: M12
- **Related SPEC**: §10.3, §12 M12

## Context

SPEC §10.3 specifies "Determinized MCTS (sampler plusieurs mains adverses
cohérentes avec l'historique, faire MCTS classique sur chaque
déterminisation, voter). Budget: ~1000 simulations / coup." with
rollouts using either random or heuristic policies.

Two empirical problems with a naïve implementation:

1. **State is already fully observable** (ADR-0002), so no
   determinization step is necessary — we don't hide opponent hands.
   "Standard MCTS on the real state" is the direct analogue.
2. **Random rollouts fail badly against a deterministic heuristic
   opponent.** First attempt was flat MCTS with random rollouts:
   budget 400, shortlist 6. Result: MCTS won **12 / 100** vs the
   heuristic — worse than random. Reason: rollouts implicitly assume
   both players play random, which grossly overestimates MCTS's
   winning chances versus a heuristic that punishes bad moves.
3. **Heuristic rollouts are too slow.** Each heuristic move requires
   evaluating ~50 candidate actions; a 100-step rollout × 1 000 sims ×
   a dozen candidates × 45 decisions per game × 100 games blows the
   test-time budget by orders of magnitude.

## Decision

The `MCTSAgent`:

1. **Shortlist top K=8** candidate actions by the 1-ply evaluator score.
2. For each shortlisted action, compute a **2-ply lookahead**: apply the
   action, simulate the opponent's best heuristic reply, evaluate the
   resulting state from our perspective.
3. Add **300 short random rollouts** (truncated at 60 steps, falling back
   to `tanh(Evaluator / 100)`) and blend their average into the score:

    ```swift
    let blended = tanh(lookaheadScore / 100) + (rolloutAvg - 0.5) * 0.5
    ```

4. Pick the action that maximises the blended score. Ties (extremely
   rare after blending) broken by list order.

For small action pools (≤ 3, typical of the draw phase) we short-circuit
to a 1-ply greedy pick — MCTS machinery is pure overhead there.

## Consequences

**Positive**

- Meets M12 DoD: MCTS beats heuristic **≥ 60 / 100**.
- Runs in ~3.5 min / 100 games in release mode — acceptable for an
  offline eval, and comfortably under the spec's budget-per-move target
  for real gameplay (1 000 sims per move is a runtime ceiling, not a
  floor).
- The blending term lets cheap random rollouts contribute a small
  discriminator when the static evaluator rates candidates as equal
  (common in the zero-score-display regime — see ADR-0008).

**Negative**

- It's not "MCTS" in the textbook UCT sense — no tree, no UCB, no
  back-propagation through a search tree. SPEC §10.3 wording is
  preserved in the class name and comments, but a purist would re-
  implement UCT on top of the same engine.
- Opponent modelling assumes the opponent is a pure 1-ply heuristic.
  Against a future MCTS-style or TD-trained opponent, the model is
  mis-specified and the agent's advantage shrinks.
- Depends on ADR-0009 (alternation during placement) — without it, the
  "next move is opponent's" assumption breaks.

## Follow-up

If M12 AI quality becomes a bottleneck, upgrade paths:

- Proper UCT tree with heuristic rollouts, caching subtrees across
  calls within a single game.
- Train the Evaluator weights offline (self-play / policy gradient).
- Once real score-display values land (SPEC §13 Q#4), re-tune the
  blend coefficients — the current `0.5` weight on rollouts was
  tuned against zeroed displays.
