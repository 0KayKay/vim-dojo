# 0005 · Habit hints always on, habit mode optional

Date: 2026-10-07 · Status: accepted

## Context

hardtime.nvim shows a hint naming a better command after an inefficient one.
delaytrain.nvim gently blocks a key that is repeated too often within a short
time. The owner found both approaches interesting for suppressing bad habits.
Our par scoring already rewards efficiency, but does not say *what* to do
instead.

## Decision

- **Habit hints** are always on: once counts are learned, a run of 3+ identical
  presses of `h j k l w b e x` produces a hint like `jjjj → 4j` in the round
  result and summary.
- **Habit mode** is optional, off by default, toggled in the menu and saved. It
  blocks the 3rd press of the same `h j k l w b e` within 1000 ms, only in
  stages where counts are learned. Blocked keys do nothing and are not counted.

## Consequences

- Blocking before counts are taught would make stage 1.1 unwinnable, hence the
  restriction.
- Habit mode uses `vim.on_key` returning `""` to discard keys (Neovim ≥ 0.11).
