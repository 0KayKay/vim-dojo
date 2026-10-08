# 0013 · Round quality limits: clunky par and chain step cost

Date: 2026-10-08 · Status: accepted

## Context

Building v0.5 surfaced two problems that the requirements in decisions 0008 and
0009 do not catch:

- Combined rounds in World 1 sometimes had a par like `k2l4l4l4l4x`. Counts for
  `h`, `l` and `x` stop at 4 (decision 0007), so a long sideways trip becomes
  the same capped move over and over. It is correct, but it teaches patience,
  not a move.
- World 4 chains were slow to generate: a chain step with `c` and typing, far
  from the cursor, with every `f`/`t` target on the line as a candidate, took up
  to 300 ms to solve, and a 3-step chain up to 730 ms.

## Decision

- A round, or a chain step, whose par repeats the same move token three times
  in a row (`4l4l4l`) is thrown away and generated again.
- Each chain step is solved with a cost limit of 12 keys
  (`solver.max_cost_chain_step`), below the 16 for edit rounds. Longer steps are
  generated again.
- Chains put at most one filler line between steps (it was two).

## Consequences

- In World 1, where only `h j k l` and counts move the cursor, combined rounds
  stay within a few cells sideways.
- The slowest 3-step chain in World 4 drops to about 460 ms; the average is
  about 130 ms. Generation runs during the pause between rounds, so the player
  rarely waits.
- Chain steps never ask for long rewrites; long typing stays in the stage
  challenges, where it is the point.
- Combined rounds in World 3 still take up to about 330 ms, because every
  `d`/`c` motion on a taller buffer is a candidate. The generation budget in
  SPEC §9 is raised from 200 ms to 400 ms per round rather than making those
  rounds simpler; the test still fails above 800 ms.
