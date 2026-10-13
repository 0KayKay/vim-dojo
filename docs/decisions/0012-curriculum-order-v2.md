# 0012 · Counts right after hjkl; whole-lines stage; 4.3 folded in

Date: 2026-10-08 · Status: accepted (supersedes the stage order in decision
0004; its vimtutor basis stays)

## Context

Playtest findings:

- Teaching counts at 2.4 meant par rewarded `jjj` for seven stages: "you
  otherwise train repeated key presses, which is not a habit you should build".
- Stage 3.2 (`dd`) was "super easy in comparison".
- Old 4.3 ("operators meet find") was the only stage that combined moves, and
  its combinations never reached a challenge.

## Decision

- World 1: `hjkl`, counts, `x`, `i a`, `A I`, boss.
- World 2: `w b`, `e`, `0 ^ $`, boss.
- World 3: `d{motion}`, `c{motion}`, whole lines (`dd`, `3dd`, `cc`, `dj`),
  boss. The lines stage comes after `c` so it can include `cc` and linewise
  operators with counts.
- World 4: `f F`, `t T`, boss. Operators with `f`/`t` (`df,`, `ct)`) are the
  combined rounds of these stages and part of the boss.
- Distances stay glanceable: at most 4 words or characters away, vertical
  targets read from the relative line numbers.

## Consequences

- 13 stages and 4 bosses instead of 14 stages.
- Horizontal counts stay capped at 4 (decision 0007), so counts are mostly
  vertical in World 1.
- Stage numbers change; saved progress is migrated by stage key (decision
  0010).
