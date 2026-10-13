# 0016 · Edit marks in place, word-aligned and live

Date: 2026-10-09 · Status: accepted

## Context

Edit rounds marked the changed characters of a plain character diff and showed
the goal as an extra virtual line under the text. The owner's second playtest:

- The marks followed git-diff logic, not words: adding `tent ` before `test`
  showed `nt te` as new; deleting `site ` showed `ite s`; in 1.4 the marks sat
  next to the line start or end instead of on it. "Not the way humans perceive
  the words."
- The extra goal line has no line number, so moving past it "kind of doesn't
  count" and throws off relative line numbers.

## Decision

- The changed span is aligned to words: a pure insertion or deletion is slid
  along the text (any position with the same result is equivalent) to the one
  that starts or ends at a word boundary, preferring one that starts with a
  letter. A replacement is widened to whole words. An insertion or deletion
  inside a word with no aligned position stays as it is, so a stray letter stays
  marked as that letter.
- Deleted text is struck through; text to type is shown as inline virtual text
  exactly where it goes (after the struck text for a replacement). No virtual
  lines are drawn, except for the rare insertion that spans lines.
- The marks are recomputed from the current text after every change (also in
  Insert mode), so they show what is left to do; typing the ghost text makes
  it disappear letter by letter.

## Consequences

- Prompts say "struck-through" and "the text shown in place" instead of "goal
  line".
- The solver and par are unaffected; marks are display only.
- Inline virtual text shifts the display but not the cursor: `l` steps over it.
  Because insertions now sit at word boundaries, this rarely matters.
