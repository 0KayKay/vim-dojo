# 0001 · A Neovim plugin in plain Lua, played in a pinned container

Date: 2026-10-07 · Status: accepted

## Context

The game must behave exactly like real Vim, since it trains muscle memory for
real editing. The owner does not want random plugins on their machine and
already plays the reference plugins inside locked-down Docker containers.

## Decision

- Vim Dojo is a Neovim plugin written in plain Lua, with no plugin or Lua-rock
  dependencies. Not a web app with a Vim emulator.
- Target Neovim 0.12.x; the container and CI pin 0.12.5 by version and SHA-256.
- The main way to play is a Docker image: no network, read-only filesystem, no
  capabilities, non-root, data volume. Installing it as a normal plugin works
  too.
- Tests use a small runner of our own (`tests/run.lua`) instead of a test
  framework, to keep zero dependencies.

## Consequences

- Real motion semantics for free; no emulator drift.
- We rely on Neovim APIs from 0.10+ (`vim.on_key` with `typed`, returning `""`
  to discard keys, `nvim_open_win` splits). Older Neovim is not supported.
- Anything a dependency would give us (UI widgets, test helpers) we write
  ourselves, kept small.
