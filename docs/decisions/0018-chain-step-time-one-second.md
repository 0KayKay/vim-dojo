# 0018 · One second per chain step, not three

Date: 2026-10-13 · Status: accepted (supersedes the per-step allowance in
decision 0015; its 5 s + 0.8 s per key stays)

## Context

Decision 0015 gave chains 3 s for every step after the first, to read the newly
highlighted target. The owner's third playtest found boss time limits "waaay
too easy": "These three seconds per new chain are completely over the top. One
is enough." After stumbling, they waited out a chain's clock and "it was ages";
the extra time made multi-step rounds easier than single ones.

The round log of that playtest (64 chains, 6 timeouts) agrees: solved chains
used a median 53 % of their time, while World 1 boss chains used 35 %.

## Decision

Chains get 1 s for every step after the first (`time_per_step_s = 1`).

## Consequences

- Replayed against the log, solved chains would use a median 61 % of their
  time and 93 % at the 90th percentile; 5 of 58 solved chains would have run
  out. That is close to how single rounds felt in 0.5, which the owner called
  "a bit tight" but fair for timed rounds.
- A 3-step chain with a total par of 14 gets 18.2 s instead of 22.2 s.
- How fast a round was solved does not yet earn anything below the time limit;
  time-based stars are proposed for the next version.
