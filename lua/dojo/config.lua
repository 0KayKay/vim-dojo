-- All tunable numbers (SPEC.md §10). Override with require("dojo").setup({...}).
local M = {}

M.defaults = {
  drill_rounds = 5,
  challenge_rounds = 8,
  challenge_focus_rounds = 4, -- rounds that use the new stage's move
  challenge_twostep_rounds = 2, -- from the stage that teaches counts on
  time_base_s = 5, -- challenge time limit = base + per_key * par
  time_per_key_s = 1,
  warn_s = 2, -- warning color in the last seconds
  star2_slack = 2, -- 2 stars when keys <= par + slack
  pass_ratio = 0.75,
  score_for_2 = 2.0,
  score_for_3 = 2.75,
  pause_success_ms = 400,
  pause_fail_ms = 1500,
  countdown_s = 3,
  habit = {
    enabled = false, -- default for new players; the menu toggle is saved
    keys = "hjklwbe",
    grace = 2, -- presses allowed within the window
    window_ms = 1000,
  },
  habit_hint_run = 3, -- run length that triggers a hint
  solver = {
    max_cost_move = 10,
    max_cost_edit = 16,
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
