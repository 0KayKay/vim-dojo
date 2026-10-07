# 0007 · Counts for single characters stop at 4

Date: 2026-10-07 · Status: accepted

## Context

With counts 2–9 for every motion, the solver found that `7x` (2 keys) beats
`dt)` (3 keys) for any span up to nine characters, and `9l` beats most `f`
jumps. Par would then reward counting letters, which no one does reliably at a
glance, and stage 4.3 drills could hardly ever require `dt,`. learn-vim and
hardtime.nvim both recommend counts for lines and words (where relative numbers
and word starts make them visible) and `f`/`t`/word motions for distances
within a line.

## Decision

The solver tries counts 2–9 for `j k w b e` and only 2–4 for `h l x`.

## Consequences

- Par for long character-wise distances uses `f`, `t`, `w`, `e` or `$`, as the
  references teach.
- Players may still type `7x`. It works and can beat par, which the game shows
  as "under par", but it is never the intended solution.
- Stage 2.4's stray-letter rounds use 3–4 letters so `3x`/`4x` stay the
  intended answer.
