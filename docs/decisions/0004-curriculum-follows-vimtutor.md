# 0004 · Curriculum order follows vimtutor

Date: 2026-10-07 · Status: accepted (supersedes the 10-stage order of spec 0.1)

## Context

Spec 0.1 taught seven motion stages before the first edit. The owner pointed to
vimtutor, learn-vim, hardtime.nvim and delaytrain.nvim as references for how
others teach Vim. vimtutor's order has been used for decades and introduces
editing (`x`, `i`, `A`) right after `hjkl`, then teaches "operator + motion" as
a grammar.

## Decision

The prototype has 14 stages in four worlds, following vimtutor lessons 1–3,
grouped by move size as learn-vim does, plus `f`/`t`, which vimtutor omits:

1. First steps: `hjkl`, `x`, `i a`, `A I`
2. Words and lines: `w b`, `e`, `0 ^ $`, counts
3. Operators: `d{motion}`, `dd`, `c{motion}`
4. Find in the line: `f F`, `t T`, operators with `f`/`t`

Explainer texts are our own words; nothing is copied from vimtutor.

## Consequences

- Edit rounds (with Insert-mode typing) exist from stage 1.2, so the engine must
  support them from the start.
- `p`, `r`, `o`, `y`, search and `gg`/`G` from vimtutor are deferred to later
  worlds (SPEC §13).
