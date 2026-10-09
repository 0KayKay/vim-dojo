-- Edit marks: aligned to words, drawn in place, updated after a change
-- (SPEC §5 Edit rounds, docs/decisions/0016).
local H = require("helpers")
local text = require("dojo.text")
local round = require("dojo.round")

local function marked(a, b)
  local p, s = text.aligned(a, b)
  return a:sub(p + 1, #a - s), b:sub(p + 1, #b - s)
end

-- the extmarks of the round namespace on a buffer, simplified
local function marks_of(buf)
  local ns = vim.api.nvim_get_namespaces()["dojo.round"]
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    local d = m[4]
    if d.virt_text then
      out[#out + 1] = { "ghost", m[2] + 1, m[3], d.virt_text[1][1] }
    elseif d.virt_lines then
      out[#out + 1] = { "lines", m[2] + 1 }
    else
      out[#out + 1] = { "struck", m[2] + 1, m[3], d.end_col }
    end
  end
  return out
end

return {
  {
    "marks follow words: tent before test, site with its space",
    function()
      H.eq({ marked("the test case", "the tent test case") }, { "", "tent " })
      H.eq({ marked("x site sock", "x sock") }, { "site ", "" })
    end,
  },
  {
    "marks sit on the line's start and end for I and A",
    function()
      H.eq({ marked("cash ring bell", "card cash ring bell") }, { "", "card " })
      H.eq({ marked("the bring", "the bring ring") }, { "", " ring" })
    end,
  },
  {
    "a stray letter or a missing letter inside a word stays as it is",
    function()
      H.eq({ marked("the maikvql lead", "the mail lead") }, { "kvq", "" })
      H.eq({ marked("the brownq fox", "the brown fox") }, { "q", "" })
      H.eq({ marked("the ln road", "the lean road") }, { "", "ea" })
    end,
  },
  {
    "a replacement is widened to whole words",
    function()
      H.eq({ marked("eat camp now", "eat cash now") }, { "camp", "cash" })
      H.eq({ marked("apple box", "apple mark") }, { "box", "mark" })
    end,
  },
  {
    "edit rounds draw the change in place, with no extra line",
    function()
      local buf = vim.api.nvim_create_buf(false, true)
      round.prepare_buffer(buf)
      vim.api.nvim_set_current_buf(buf)
      round.start({
        buf = buf,
        win = vim.api.nvim_get_current_win(),
        task = { kind = "edit", lines = { "the test case" }, cursor = { 1, 4 }, goal_lines = { "the tent test case" } },
        on_done = function() end,
      })
      H.eq(marks_of(buf), { { "ghost", 1, 4, "tent " } })
      round.abort()
    end,
  },
  {
    "after a change the marks show what is left",
    function()
      local buf = vim.api.nvim_create_buf(false, true)
      round.prepare_buffer(buf)
      vim.api.nvim_set_current_buf(buf)
      round.start({
        buf = buf,
        win = vim.api.nvim_get_current_win(),
        task = { kind = "edit", lines = { "the brownqz fox" }, cursor = { 1, 9 }, goal_lines = { "the brown fox" } },
        on_done = function() end,
      })
      H.eq(marks_of(buf), { { "struck", 1, 9, 11 } })
      H.type("x")
      H.settle(20)
      H.eq(marks_of(buf), { { "struck", 1, 9, 10 } })
      round.abort()
    end,
  },
  {
    "j and k see the ghost text in play and in the solver alike",
    function()
      local solver = require("dojo.solver")
      local marks = require("dojo.marks")
      local lines = { "aaaa bbbb cccc dddd", "the test case word" }
      local goal = { "aaaa bbbb cccc dddd", "the tent test case word" }
      local task = { kind = "edit", lines = lines, cursor = { 1, 12 }, goal_lines = goal }
      -- in a real window: the ghost "tent " takes screen columns 4-8 on line 2
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      marks.edit(buf, vim.api.nvim_create_namespace("dojo.test.marks"), lines, goal)
      vim.api.nvim_win_set_cursor(0, { 1, 12 })
      vim.cmd("normal! j")
      local real = vim.api.nvim_win_get_cursor(0)
      H.eq(real, { 2, 7 }, "j lands straight below on screen")
      H.eq(solver.run(task, { { keys = "j" } }).cursor, real, "the solver agrees")
    end,
  },
}
