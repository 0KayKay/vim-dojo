# 0010 · Stable stage keys; progress migration

Date: 2026-10-08 · Status: accepted

## Context

Version 1 of `progress.json` keyed stages by their display number ("2.4").
Reordering the curriculum (decision 0012) changes those numbers, so saved stars
would attach to the wrong stages. The owner has real progress from playtesting.

## Decision

- Every stage has a stable `key` (`hjkl`, `counts`, `x`, `insert`, `append`,
  `word`, `word_end`, `line_edges`, `delete`, `change`, `lines`, `find`, `till`,
  `boss_1` … `boss_4`). Stage files are named after it. Display ids (`1.2`,
  `2.B`) are computed from the order and never saved.
- `progress.json` version 2 is keyed by stage key. A version 1 file is migrated
  on load: old 1.1 → hjkl, 1.2 → x, 1.3 → insert, 1.4 → append, 2.1 → word,
  2.2 → word_end, 2.3 → line_edges, 2.4 → counts, 3.1 → delete, 3.2 → lines,
  3.3 → change, 4.1 → find, 4.2 → till; old 4.3 is dropped.
- A stage that already has a star stays unlocked even if the entry before it
  (for example a new boss) has none. A stage that was open in the version 1
  save (the first one, or the one after a passed stage) is marked open during
  migration, so v1 2.1 stays playable after passing 1.4 although the new 1.B
  now sits in front of it.

## Consequences

- Future reorders need no migration as long as keys stay.
- Migrated players keep their stars and can play everything they had unlocked;
  bosses are new for them.
