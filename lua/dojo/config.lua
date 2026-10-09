-- All tunable numbers (SPEC.md §10). Override with require("dojo").setup({...}).
local M = {}

M.defaults = {
  drill_basic_rounds = 3, -- the new move on its own
  drill_combined_rounds = 3, -- the new move with one you know (decision 0008)
  challenge_rounds = 8, -- every one needs the new move
  challenge_combined_rounds = 5, -- the main lever for a future difficulty setting
  boss_mixed_rounds = 6,
  boss_chains = { 2, 2, 3, 3 }, -- steps per chain round, played last (decision 0009)
  time_base_s = 5, -- time limit = base + per_key * par (challenges and bosses)
  time_per_key_s = 0.8,
  time_per_step_s = 3, -- chains: reading time for every step after the first (decision 0015)
  warn_s = 2, -- warning color in the last seconds
  star2_slack = 2, -- 2 stars when keys <= par + slack
  pass_ratio = 0.75,
  score_for_2 = 2.0,
  score_for_3 = 2.75,
  pause_success_ms = 400,
  pause_fail_ms = 1500,
  countdown_s = 3,
  habit = {
    enabled = true, -- default for new players; the menu toggle is saved (decision 0011)
    keys = "hjklwbe",
    grace = 3, -- presses in a row allowed within the window; the next is blocked (decision 0014)
    window_ms = 1000,
  },
  habit_hint_run = 3, -- run length that triggers a hint
  solver = {
    max_cost_move = 10,
    max_cost_edit = 16,
    max_cost_chain_step = 12, -- longer steps make chains slow to generate and to read
    alt_slack = 2, -- alternatives up to par + slack
  },
  generate_tries = 60,
  quit_on_close = false, -- the Docker image sets this: closing the menu quits Neovim
  data_dir = nil, -- default: stdpath("data") .. "/dojo"
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
