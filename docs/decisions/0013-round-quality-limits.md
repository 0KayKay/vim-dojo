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

- A round, or a chain step, whose par uses the same move token three times
  (`4l4l4l`, or `4l4ll4l` with a step in between) is thrown away and generated
  again.
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
- Combined rounds in Worlds 3 and 4 still take up to about 450 ms, because
  every `d`/`c` motion on a taller buffer is a candidate. The generation budget
  in SPEC §9 is raised from 200 ms to 500 ms per round rather than making those
  rounds simpler; the test still fails above 800 ms.

## Addendum: tie-break by smaller counts

The first playthrough of a combined 3.1 round showed `09bd$` as the intended
solution: back nine words across two lines, as short as `2kwd$` and chosen only
because `0` sorts before `2`. Among equally short solutions with as many
commands, the solver now prefers the smaller sum of counts, which favors
glanceable distances (`2k`, `w`) over long wrapped counts.

## Addendum: operators stay on their line

A World 4 chain's intended last step was `0kcbmark<Esc>`: from column 0, `cb`
reaches back to the last word of the line above, and Vim's rule for exclusive
motions that end in column 1 keeps the newline. It beat the readable
`bc$mark<Esc>`-style answers by a key or two. A learner cannot be expected to
find or understand that, so the solver now drops `d`/`c` with a charwise
motion whenever the edit changes any line other than the cursor's. Motions
alone may still cross lines (`b` back to the line above is fine).
