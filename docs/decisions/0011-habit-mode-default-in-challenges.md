# 0011 · Habit mode on by default, in challenges and bosses only

Date: 2026-10-08 · Status: accepted (supersedes the "off by default" part of
decision 0005)

## Context

The playtester never tried habit mode ("nothing led to it, feels a bit like a
gimmick") and suggested enabling it by default in challenges once counts are
learned. With counts now taught at stage 1.2, repeated presses are almost never
the best answer after that.

## Decision

- Habit mode is on by default (existing saves are switched on during migration)
  and still toggled with `H`.
- It blocks only in challenges and bosses, and only once counts are learned.
  Drills never block.
- The character after `f`, `t`, `r` and similar keys is never blocked.

## Consequences

- Mashing `jjjj` stops working in timed rounds, so "stumbling through" is a
  little harder there; drills stay forgiving, in line with decision 0002.
- The counts explainer mentions habit mode so players know why a key is
  ignored.
