# 0002 · Score keystrokes against par instead of restricting input

Date: 2026-10-07 · Status: accepted

## Context

vim-be-good accepts any solution that is fast enough, so clumsy habits pass.
nvim-training is strict about how a task is solved, which stops cheating but
feels like a puzzle when you don't know the expected move. The owner wants the
game to "not punish you for being inexperienced, but reward you for mastering
it".

## Decision

Every round has a par: the fewest keystrokes that solve it with the moves
learned so far. Any solution counts as solved; stars depend on how close the
keystroke count is to par (3 at par, 2 within par + 2, 1 otherwise, 0 on
timeout). Challenges add a clock. The intended solution and alternatives are
always shown afterwards, in Vim key notation, instead of an animated demo.

## Consequences

- Par must be correct, or scoring feels unfair. That makes the solver
  (decision 0003) the most important component, and it is tested hardest.
- Mashing keys still finishes a round, which keeps beginners moving.
- Key notation is enough to show solutions; no animation code is needed.
