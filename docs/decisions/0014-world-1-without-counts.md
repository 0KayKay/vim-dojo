# 0014 · World 1 without counts; no counts for h and l

Date: 2026-10-09 · Status: accepted (supersedes the counts placement in
decision 0012, the `h l` part of decision 0007, and the "third press" rule of
decision 0011)

## Context

The owner's second playtest found World 1, and its boss above all, far harder
than Worlds 2 and 3, and named the reason: rounds asked for sideways travel with
counts on `h` and `l` (`4l4ll4l`, `2h4hj4h`), which is not how anyone moves.
"Counting the letters you need to traverse by eye is just punishing and hard."
Over a few cells people press `l` two or three times; further away they use `w`,
`b`, `e`, `f`/`t`, or wipe the word with `cw` and retype it. Plucking letters out
of the middle of a word with `4x` felt just as unnatural.

The round log agrees. In 0.4, World 1 rounds with a par like
`hhhhhhhhhhhxxx` were solved with `b` and `w` before those were taught. In 0.5,
World 1 boss chains timed out a third of the time, and the World 1 average stars
were no better than later worlds despite the simpler moves.

## Decision

- World 1 is `h j k l`, `x`, `i a`, `A I` and its boss, without counts. Counts
  open World 2 (2.1), before `w b`.
- `h` and `l` never take a count in the solver, in any world. `x` keeps counts
  2–4, and `w b e` now stop at 4 as well (they were 2–9): the round log showed
  World 2 chains timing out on pars like `7b` and `8be`, which wrap across
  lines and have to be counted word by word. `j` and `k` keep 2–9, read off the
  relative line numbers.
- Distances are natural: in World 1 a target is at most 3 lines and 3 cells
  away; everywhere, a par with more than 3 presses of `h`/`l` or `j`/`k`, or the
  same counted move three times is regenerated.
- Stray letters for `x` are 1 or 2, at the start or end of a word, near the
  cursor. In 1.4 (`A I`) the cursor starts mid-line so `A`/`I` are the point.
- Habit mode blocks the fourth press of a key in a row, not the third, as
  hardtime.nvim does by default: `lll` is the natural way to move three cells
  and must never be blocked. It still applies only once counts are learned.

## Consequences

- The `counts` stage keeps its key (saved progress is unaffected) but moves
  from 1.2 to 2.1 and teaches `j`/`k` counts and `x` counts only.
- World 1 rounds and the World 1 boss are short hops; the challenge comes from
  combining moves, not from counting.
- In later worlds, long sideways moves are always word motions, `f`/`t`, line
  edges or `c`, which is what the references recommend.
- Habit hints (`jjjj → 4j`) no longer mention `h` and `l`.
