# 0015 · Clock set from the round log: 5 s + 0.8 s per key + 3 s per chain step

Date: 2026-10-09 · Status: accepted (replaces the 0.5 clock of 4 s + 0.7 s per
key)

## Context

0.5 tightened the clock from 5 s + 1.0 s per key to 4 s + 0.7 s. The owner's
second playtest called it harsh ("the moment I finished the last keystroke, the
timeout was shown"), especially in bosses, and suggested 0.8 s per key. The
round log of that playtest (575 rounds) showed:

- Single rounds: 8 % to 15 % timed out; solved rounds used a median 53 % and at
  the 90th percentile 84 % of their time.
- Chains: 51 % timed out (64 % in the World 2 boss); solved chains used a median
  89 % of their time. Short chains failed most: each step needs time to find
  the newly highlighted target, which par does not measure.

## Decision

The limit is 5 s + 0.8 s per par key, plus 3 s for every chain step after the
first. Replayed against the log, solved rounds would use a median 44 % and a
90th percentile 70 % of the new limit; solved chains a median 57 % and 66 %.

## Consequences

- Single rounds get about 20 % more time, chains about 50 % more.
- The clock still matters: a player who has to think about every move runs out
  of time, which is the point of challenges.
- A tighter clock is left for a future difficulty setting.
