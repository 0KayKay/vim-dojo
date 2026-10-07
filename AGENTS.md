# Working on Vim Dojo

Rules for anyone changing this repo: AI agents (Claude Code, Codex, …) and
humans alike. Read this first, then follow it.

## Start here

1. [SPEC.md](SPEC.md): what the game does. The source of truth for behavior.
2. [docs/decisions/](docs/decisions/): why things are the way they are.
3. [docs/references.md](docs/references.md): who inspired what (credit).
4. [docs/playtests.md](docs/playtests.md): what players noticed and what changed.

## Rules of thumb

1. **Spec first.** A change in behavior starts in `SPEC.md`, in the same branch
   as the code and committed before it. If code and spec disagree, the spec
   wins, unless you change the spec on purpose and say so in the PR.
2. **Write down decisions.** Anything someone might later ask "why?" about (a
   dependency, an architecture choice, a game rule, a default with a reason)
   gets a short record in `docs/decisions/NNNN-slug.md`: Context, Decision,
   Consequences. Never rewrite an old record; add a new one that supersedes it.
3. **Tests are the contract.** `make test` must pass before every commit you
   push. New engine behavior gets a test. A new stage is covered automatically
   by the 200-seed stage test once it is listed in `lua/dojo/curriculum.lua`.
4. **No new dependencies** (Neovim plugins, Lua rocks, tools in the image)
   without a decision record. Versions stay pinned: Neovim version and
   checksums live in `docker/Dockerfile` and `.github/workflows/ci.yml`; change
   both together.
5. **Stay a good guest in Neovim.** Everything the game sets is buffer-, window-
   or tab-local and goes away when the game closes. No global keymaps or options.
6. **Credit inspiration.** Ideas taken from other projects go into
   `docs/references.md`. Don't copy code or text from them unless their license
   allows it, and then credit it in the file itself.
7. **Small branches, green CI.** Branch from `main`, open a pull request, merge
   only with CI green. Commit messages: short imperative summary line, body
   explains why.
8. **Playtesting beats guessing.** Difficulty numbers live in
   `lua/dojo/config.lua`. Change them after someone played, and note it in
   `docs/playtests.md`.

## Commands

| Command | What it does |
| --- | --- |
| `make test` | Run the headless test suite with the `nvim` on your PATH (needs Neovim ≥ 0.12) |
| `make test NVIM=/path/to/nvim` | Same, with a specific Neovim binary |
| `make play` | Build the image and play: `docker compose run --rm dojo` |
| `make dev` | Play the working copy without rebuilding: `docker compose run --rm dev` |
| `make docker-test` | Run the test suite inside the image: `docker compose run --rm test` |

## Layout

```
SPEC.md                 behavior (source of truth)
AGENTS.md               this file; CLAUDE.md points here
plugin/dojo.lua         :Dojo command
lua/dojo/               the game (see SPEC.md §9 for each module)
lua/dojo/stages/        one file per stage
tests/                  headless tests, runner in tests/run.lua
docker/                 Dockerfile and the container's init.lua
compose.yaml            dojo / dev / test services
docs/decisions/         decision records
docs/references.md      credits
docs/playtests.md       playtest notes
.github/workflows/      CI
```

## Adding a stage

1. Add the stage to the curriculum table in `SPEC.md` §7 (keys, round kind,
   what rounds look like).
2. Create `lua/dojo/stages/<id>.lua` following the contract in SPEC.md §9. If it
   teaches a new kind of key, add the move family in `lua/dojo/moves.lua`.
3. List it in `lua/dojo/curriculum.lua`.
4. `make test`: the stage test generates 200 rounds per mode and replays every
   solution. Fix the generator until it passes, then play it once yourself.

## Definition of done

- Spec updated (and its history table, for behavior changes).
- Tests added or updated; `make test` green locally and in CI.
- Decision record written if a choice was made.
- README or docs updated if a command or workflow changed.
