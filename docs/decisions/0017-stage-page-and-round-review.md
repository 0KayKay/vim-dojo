# 0017 · Stage page on <CR>; review and replay rounds from a summary

Date: 2026-10-09 · Status: accepted

## Context

From the owner's second playtest:

- `<CR>` in the menu continued a played stage straight into its challenge,
  which "caught me off guard" when coming back to a stage to compare versions.
- After a disappointing score, there was no way to look at a round again: "you
  cannot quite remember the setup", and a post-mortem would help to "understand
  how to do it better". The `<Tab>` hint went unused because there is no time
  for it during a timed round.

## Decision

- `<CR>` in the menu opens the stage page (the explainer). Its status line says
  what `<CR>` starts there: the drill until it has been done once, then the
  challenge. `d` and `c` still start either one directly, from the menu or the
  page.
- In every summary the cursor sits on the rounds; `<CR>` opens the round under
  it as it started, with its marks, and the header shows your keys, par, the
  intended solution and alternatives. `p` plays it again untimed; nothing is
  saved or scored. `q` returns to the summary. `n` (no longer `<CR>`) moves on.
- When a round timed out, the summary adds a one-line tip that `u` undoes a
  slip.

## Consequences

- One more key press to start a stage from the menu, in exchange for always
  seeing what the stage is about and which step comes next.
- Rounds are kept in memory only for the summary on screen; the round log keeps
  seeds, so a later "replay any past round" could rebuild them.
