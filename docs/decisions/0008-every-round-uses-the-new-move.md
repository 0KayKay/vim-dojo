# 0008 · Every challenge round uses the new move; most combine it

Date: 2026-10-08 · Status: accepted (supersedes the challenge composition in
spec 0.2–0.4)

## Context

Until spec 0.4, half of each challenge came from earlier stages' generators.
Those generators know only their own move, so the owner's playtest
(docs/playtests/2026-10-08-owner.md) found challenges "just repeat moves you
learned in the past without context … mindlessly repeating katas". Combinations
appeared only where one command needs two concepts (operator + motion), which
is why World 3 and old stage 4.3 felt different.

## Decision

- Every challenge round's intended solution must use the stage's move.
- 5 of 8 challenge rounds, and the second half of each drill, are *combined*:
  the intended solution also uses another move family. Counts alone don't count
  as a combination, because they modify a move rather than add one.
- Requirements are checked with the solver's concept tags (every candidate key
  knows its move families), not assumed from how a round was generated.
  Rounds that miss them are regenerated.
- Combined rounds come from a stage's own `combined` generator or from a generic
  combine step: the basic task in a taller buffer with the cursor moved away.
- Older moves come back as the partner in combined rounds and in bosses
  (decision 0009), not as separate rounds.

## Consequences

- "Combined rounds per challenge" becomes the main difficulty lever.
- Rounds are tailored so the new move is optimal. Choosing freely between moves
  is left to bosses.
- Generation needs more attempts per round; the per-round time budget still
  holds (measured in tests).
