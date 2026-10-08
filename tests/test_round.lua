-- The round runner with real typed keys (SPEC §5).
local H = require("helpers")
local round = require("dojo.round")
local config = require("dojo.config")

local function setup_window()
  local buf = vim.api.nvim_create_buf(false, true)
  round.prepare_buffer(buf)
  vim.api.nvim_set_current_buf(buf)
  return buf, vim.api.nvim_get_current_win()
end

local function run(task, keys_list, opts)
  opts = opts or {}
  local buf, win = setup_window()
  local result
  round.start(vim.tbl_extend("force", {
    buf = buf,
    win = win,
    task = task,
    on_done = function(r)
      result = r
    end,
  }, opts))
  for _, k in ipairs(keys_list) do
    H.type(k)
  end
  H.settle(30)
  return result, buf
end

local move = {
  kind = "move",
  lines = { "the quick brown fox jumps over" },
  cursor = { 1, 0 },
  goal = { 1, 16 },
}

return {
  {
    "a move round succeeds and counts typed keys",
    function()
      -- a count and its motion go in one feed: each feed acts like :normal
      local r = run(move, { "3w" })
      H.ok(r and r.solved, "round should be solved")
      H.eq(r.count, 2)
      H.eq(vim.tbl_map(function(k)
        return k.k
      end, r.keys), { "3", "w" })
    end,
  },
  {
    "landing on the target mid-way counts",
    function()
      local r = run(move, { "w", "w", "w" })
      H.ok(r and r.solved)
      H.eq(r.count, 3)
    end,
  },
  {
    "<Esc> in Normal mode is free",
    function()
      local r = run(move, { "<Esc>", "<Esc>", "3w" })
      H.eq(r.count, 2)
    end,
  },
  {
    "move rounds are read-only",
    function()
      local _, buf = run(move, { "x" })
      H.eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), move.lines)
      round.abort()
    end,
  },
  {
    "an edit round ends after <Esc>, which counts",
    function()
      local task = {
        kind = "edit",
        lines = { "the brown fox" },
        cursor = { 1, 4 },
        goal_lines = { "the quick brown fox" },
      }
      local buf, win = setup_window()
      local result
      round.start({
        buf = buf,
        win = win,
        task = task,
        on_done = function(r)
          result = r
        end,
      })
      H.type("iquick <Esc>")
      H.settle(30)
      H.ok(result and result.solved, "solved after <Esc>")
      H.eq(result.count, 8, "i + 6 typed characters + <Esc>")
    end,
  },
  {
    "an edit round is solved with x",
    function()
      local task = { kind = "edit", lines = { "brqown" }, cursor = { 1, 2 }, goal_lines = { "brown" } }
      local r = run(task, { "x" })
      H.ok(r and r.solved)
      H.eq(r.count, 1)
    end,
  },
  {
    "time runs out",
    function()
      local now = 0
      local saved = round.clock
      round.clock = function()
        return now
      end
      local buf, win = setup_window()
      local result
      round.start({
        buf = buf,
        win = win,
        task = move,
        limit_ms = 5000,
        on_done = function(r)
          result = r
        end,
      })
      now = 5001
      round._tick()
      H.settle(20)
      round.clock = saved
      H.ok(result and not result.solved, "should time out")
    end,
  },
  {
    "the hint is recorded",
    function()
      local buf, win = setup_window()
      local result, hinted = nil, false
      round.start({
        buf = buf,
        win = win,
        task = move,
        on_done = function(r)
          result = r
        end,
        on_hint = function()
          hinted = true
        end,
      })
      H.type("<Tab>")
      H.type("3w")
      H.settle(30)
      H.ok(hinted)
      H.ok(result.hint)
      H.eq(result.count, 2, "<Tab> is not counted")
    end,
  },
  {
    "habit mode blocks the third press, not counted",
    function()
      local lines = {}
      for i = 1, 8 do
        lines[i] = "line number " .. i
      end
      local task = { kind = "move", lines = lines, cursor = { 1, 0 }, goal = { 6, 0 } }
      local blocked = 0
      local r = run(task, { "j", "j", "j", "3j" }, {
        habit = true,
        on_blocked = function()
          blocked = blocked + 1
        end,
      })
      H.ok(r and r.solved, "2 j + 3j reach line 6")
      H.eq(r.count, 4)
      H.eq(r.blocked, 1)
      H.eq(blocked, 1)
    end,
  },
  {
    "habit mode never blocks the character after f",
    function()
      local task = { kind = "move", lines = { "abc def efg hij" }, cursor = { 1, 0 }, goal = { 1, 8 } }
      local r = run(task, { "e", "e", "fe" }, { habit = true })
      H.ok(r and r.solved, "e e fe reaches the e of efg")
      H.eq(r.blocked, 0)
      H.eq(r.count, 4)
      H.eq(r.keys[4].mode, "arg")
    end,
  },
  {
    "mouse keys are ignored",
    function()
      local buf, win = setup_window()
      local result
      round.start({
        buf = buf,
        win = win,
        task = move,
        on_done = function(r)
          result = r
        end,
      })
      H.type("<LeftMouse>")
      H.type("3w")
      H.settle(30)
      H.eq(result.count, 2)
    end,
  },
  {
    "without habit mode repeats are fine",
    function()
      local task = { kind = "move", lines = { "a", "b", "c", "d" }, cursor = { 1, 0 }, goal = { 4, 0 } }
      local r = run(task, { "j", "j", "j" })
      H.ok(r and r.solved)
      H.eq(r.count, 3)
    end,
  },
  {
    "config is untouched by rounds",
    function()
      H.eq(config.get().habit.grace, 2)
    end,
  },
  {
    "a chain counts steps in order, edits included",
    function()
      local steps = {}
      local task = {
        kind = "chain",
        lines = { "alpha beta gamma", "one twxo three" },
        cursor = { 1, 0 },
        steps = {
          { kind = "move", row = 2, goal_col = 6, line = "one twxo three" },
          { kind = "move", row = 1, goal_col = 6, line = "alpha beta gamma" },
          { kind = "edit", row = 2, line = "one twxo three", goal_line = "one two three" },
        },
      }
      -- w lands on step 2's target first; it only counts once step 1 is done
      local r, buf = run(task, { "w", "j", "k", "j", "x" }, {
        on_step = function(i)
          steps[#steps + 1] = i
        end,
      })
      H.ok(r and r.solved, "chain should be solved")
      H.eq(r.count, 5)
      H.eq(r.steps_done, 3)
      H.eq(steps, { 2, 3 })
      H.eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "alpha beta gamma", "one two three" })
    end,
  },
  {
    "in a chain, the text can only change during edit steps",
    function()
      local buf, win = setup_window()
      round.start({
        buf = buf,
        win = win,
        task = {
          kind = "chain",
          lines = { "alpha beta", "one twxo" },
          cursor = { 1, 0 },
          steps = {
            { kind = "move", row = 1, goal_col = 6, line = "alpha beta" },
            { kind = "edit", row = 2, line = "one twxo", goal_line = "one two" },
          },
        },
        on_done = function() end,
      })
      H.eq(vim.bo[buf].modifiable, false, "move step")
      H.type("x")
      H.eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "alpha beta")
      H.type("w")
      H.settle(30)
      H.eq(vim.bo[buf].modifiable, true, "edit step")
      round.abort()
    end,
  },
  {
    "a chain step starts with the column j and k remember, as in play",
    function()
      local solver = require("dojo.solver")
      local compose = require("dojo.compose")
      local learned = H.learned({ "hjkl", "line" })
      local lines = { "short", "a much longer line here" }
      local steps = {
        { kind = "move", row = 1, goal_col = 4, line = lines[1] },
        { kind = "move", row = 2, goal_col = 22, line = lines[2] },
      }
      local sub1 = compose.step_task(steps[1], lines, { 1, 0 })
      local sol1 = solver.solve(sub1, learned)
      H.eq(sol1.keys, "$")
      local state = solver.run(sub1, sol1.tokens)
      local sol2 = solver.solve(compose.step_task(steps[2], state.lines, state.cursor, state.curswant), learned)
      H.eq(sol2.keys, "j", "after $, j keeps to the line end")
      -- and the round runner agrees
      local r = run({ kind = "chain", lines = lines, cursor = { 1, 0 }, steps = steps }, { "$", "j" })
      H.ok(r and r.solved, "chain solved with $ then j")
      H.eq(r.count, 2)
    end,
  },
}
