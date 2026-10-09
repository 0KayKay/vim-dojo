# Vim Dojo

Learn Vim motions as a game, inside real Neovim. Each stage teaches one move,
drills it, then throws you into a timed challenge that mixes it with everything
you learned before. Every round has a **par**, the fewest keystrokes that solve
it, so clumsy solutions still pass while clean ones earn stars.

> Status: prototype under construction. The behavior is specified in
> [SPEC.md](SPEC.md).

## Play

With Docker (recommended: nothing gets installed on your machine, and the
container has no network access):

```sh
git clone https://github.com/0KayKay/vim-dojo
cd vim-dojo
docker compose run --rm dojo
```

Progress is kept in a Docker volume between sessions. Quit with `q` in the menu.

As a plugin in your own Neovim (0.12 or newer), add this repo with your plugin
manager and run `:Dojo`. Custom keymaps can interfere with rounds; the game
assumes stock Neovim.

## How it plays

- **Explainer:** what the new move does and what it combines with, in Vim key
  notation.
- **Drill:** 6 untimed rounds, first the move alone, then combined with moves
  you know. `<Tab>` shows a hint.
- **Challenge:** 8 timed rounds; every one needs the new move, most combine it.
  1 star unlocks the next stage.
- **Boss:** at the end of each world, mixed rounds and chains of 2–3 steps. It
  shows your weakest move. Beat a boss early to skip ahead.
- **Habit mode** (on by default, `H` in the menu): in timed rounds, blocks a
  motion key pressed four times in a row once you have learned counts.
- **Look back:** in any summary, `<CR>` on a round shows how it started next to
  your keys and the intended solution; `p` plays it again without a clock.

## Develop

Read [AGENTS.md](AGENTS.md) first; it holds the rules for humans and AI agents.

```sh
make test          # headless tests with your local nvim (0.12+)
make dev           # play the working copy in the container, no rebuild
make docker-test   # run the tests inside the pinned image
```

## Credits

Inspired by vim-be-good, nvim-training, vimtutor, learn-vim, hardtime.nvim and
delaytrain.nvim. See [docs/references.md](docs/references.md) for details.
