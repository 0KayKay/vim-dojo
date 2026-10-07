# Playtest notes

Newest first. For each session: date, who played, which stages, what felt off,
and what changed as a result (with the config value or commit).

| Date | Player | Stages | Notes | Changes |
| --- | --- | --- | --- | --- |
| 2026-10-07 | Claude (in the container, 80 × 24 terminal via tmux) | 1.1 drill + challenge, 1.2, 2.1, 2.4 with habit mode, 3.3, 4.3 | Menu, explainer, countdown, clock, time-out feedback, goal line and habit blocking all worked. Found: menu cursor jumped to the last stage after `:q`; "Learned:" line overflowed 80 columns; before/after in the explainer looked identical without labels; `gg` in the menu landed on the title; 4.3 spans could cover a whole line; summary columns touched when keys were long. Solver: `7x` beat `dt)` (decision 0007); change rounds took up to 8 s before pruning. | Menu remembers the stage; "Learned:" uses spaces; explainer labels before/type/after; `gg`/`G` mapped; 4.3 spans ≤ 18 columns; summary column gaps; count limits; solver pruning (SPEC 0.3) |
