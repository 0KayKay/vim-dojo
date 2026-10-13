# 0009 · World bosses with chains, a concept report and skip ahead

Date: 2026-10-08 · Status: accepted

## Context

The playtest asked for a boss at the end of each world: harder, longer, chaining
several concepts in sequence, mixing concepts that can't be combined in one
command, and tracking which concepts each round used so the weakest move can be
found. The playtester also found World 1 "fairly basic", while a real beginner
needs it.

## Decision

- Each world ends with a boss: 10 timed rounds, 6 *mixed* (at least two move
  families, at least one from this world) and 4 *chains* of 2, 2, 3 and 3 steps.
- A chain stacks single-line tasks from several stages on separate lines of one
  buffer; steps are done in order, one highlighted at a time. Move and edit
  steps can follow each other, which is how incompatible concepts meet.
- Chain par is the sum of the step pars along the intended path, computed when
  the round is generated, not while playing.
- The boss summary reports average stars per move family (from the intended
  solutions' concept tags) and names the weakest with the stage to replay.
- A boss is playable as soon as its world's first stage is unlocked. Beating it
  unlocks the whole world and the next one (skip ahead).

## Consequences

- Experienced players can test out of a world; beginners lose nothing.
- Chain par is approximate when a player ends a step somewhere else; the
  par + 2 slack for 2 stars absorbs that.
- Concept tags are logged for every round, ready for a later habit or weakness
  report across sessions.
