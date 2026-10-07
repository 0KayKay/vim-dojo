# 0006 · Defaults for the questions left open in spec 0.1

Date: 2026-10-07 · Status: accepted, to be revisited after playtesting

## Context

Spec 0.1 listed open questions, each with a proposed answer. The owner reviewed
the spec, found it good and kept the name, without objecting to any proposal.

## Decision

| Question | Decision |
| --- | --- |
| Name | "Vim Dojo"; repo `vim-dojo`; command `:Dojo` |
| Drill timer | Drills are untimed; only challenges have a clock |
| Unlock rule | 1 star (pass) unlocks the next stage |
| After a failed round | Keep the flow: show the solution, continue after 1.5 s |
| Controls in a round | `<Tab>` hint, `:q` back to the menu |
| World 2 in the prototype | Yes; now part of a four-world prototype (decision 0004) |
| Menu style | `j`/`k` and `<CR>`, not vim-be-good's delete-a-line |

## Consequences

All of these are numbers or flags in `lua/dojo/config.lua` or small UI choices,
cheap to change after playtesting. Record any change in `docs/playtests.md` and,
for rules, in a new decision.
