# 0003 · Find par by running real Neovim commands

Date: 2026-10-07 · Status: accepted

## Context

Par has to be the true shortest solution. Hand-computing it per task type is
error-prone because Vim's rules have many special cases (`cw` acts like `ce`,
`e` from the end of a word, `j` keeping the column after `$`). A pure-Lua model
of motions would drift from real Neovim in the same places.

## Decision

The solver runs candidate keys with `normal!` in a hidden scratch buffer and
does a uniform-cost search ordered by keystroke count (a count prefix costs its
digits). State = text, cursor and `curswant`. Candidates are limited to learned
moves. Insert-mode commands are tried as finishers whose typed text is derived
from the goal with a sentinel character. Edits are pruned unless the result can
still become the goal.

A benchmark on 0.12.5 (2026-10-07) measured 20–200 ms per round with the full
World 1–2 move set, about 4.5 µs per candidate. Searching by command count
instead of key count gave wrong par (`2k9b` instead of `3kw`), so cost must be
keys.

## Consequences

- Correct par by construction for anything we can express as keys.
- Solving costs real time, so rounds are generated one ahead during the pause
  between rounds rather than while the player is typing.
- If later worlds make the search too slow, the fallback is a pure-Lua model for
  the slow parts, cross-checked against this solver in tests.
- `vim.on_key` also sees the solver's `normal!` keys; they arrive with an empty
  `typed` argument, and the round only counts typed keys, so they never leak
  into a score.
