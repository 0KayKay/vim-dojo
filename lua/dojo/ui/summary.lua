-- After every drill and challenge: every round, your keys vs. the intended
-- solution (SPEC.md §8 Summary).
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local curriculum = require("dojo.curriculum")
local score = require("dojo.score")

local M = {}

local last -- { s, sum }
local mapped = false

local function map(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  local function retry()
    require("dojo.session").start(last.s.id, last.s.mode)
  end
  local function onward()
    local s, sum = last.s, last.sum
    if s.mode == "drill" then
      require("dojo.session").start(s.id, "challenge")
    elseif sum.pass and curriculum.next(s.id) then
      require("dojo.ui.menu").continue(curriculum.next(s.id))
    else
      require("dojo.ui.menu").show(s.id)
    end
  end
  vim.keymap.set("n", "r", retry, o)
  vim.keymap.set("n", "n", onward, o)
  vim.keymap.set("n", "<CR>", onward, o)
  for _, k in ipairs({ "m", "q" }) do
    vim.keymap.set("n", k, function()
      require("dojo.ui.menu").show(last.s.id)
    end, o)
  end
end

local function your_keys(r)
  local parts = {}
  for _, k in ipairs(r.result and r.result.keys or {}) do
    parts[#parts + 1] = k.k
  end
  return table.concat(parts)
end

function M.show(s, sum, newbest)
  last = { s = s, sum = sum }
  local buf, win = layout.show("summary")
  if not mapped then
    map(buf)
    mapped = true
  end
  local width = vim.api.nvim_win_get_width(win)
  local head = string.format(" %s %s · %s complete", s.stage.id, s.stage.title, s.mode == "drill" and "Drill" or "Challenge")
  local right = s.mode == "challenge" and string.format("%s   score %.2f ", score.stars_text(sum.stars), sum.score) or ""
  local rows = {
    {
      { head, "DojoTitle" },
      { string.rep(" ", math.max(1, width - render.width(head) - render.width(right))) },
      { right, "DojoStar" },
    },
    "",
  }
  local stats = string.format(
    " Solved %d/%d · at par %d/%d · average %.1f s · seed %d",
    sum.solved,
    sum.rounds,
    sum.at_par,
    sum.rounds,
    sum.avg_time_s,
    s.seed
  )
  local line = { { stats } }
  if newbest then
    line[#line + 1] = { "   new best!", "DojoOk" }
  end
  if s.mode == "challenge" and not sum.pass then
    local need = math.ceil(require("dojo.config").get().pass_ratio * sum.rounds - 1e-9)
    line[#line + 1] = { string.format("   solve %d of %d to pass", need, sum.rounds), "DojoWarn" }
  end
  rows[#rows + 1] = line
  rows[#rows + 1] = ""
  rows[#rows + 1] = {
    { "  #  " .. render.fit("your keys", 16) .. render.fit("par", 5) .. render.fit("intended", 15) .. render.fit("also works", 18) .. "stars", "DojoDim" },
  }
  for i, r in ipairs(s.rounds) do
    local alts = {}
    for _, a in ipairs(r.alts or {}) do
      alts[#alts + 1] = a.display
    end
    local stars = r.solved and { score.stars_text(r.stars), "DojoStar" } or { "time out", "DojoBad" }
    local row = {
      { string.format(" %2d  ", i) },
      { render.fit(your_keys(r), 15) .. " " },
      { render.fit(tostring(r.par), 5) },
      { render.fit(r.sol.display, 14) .. " ", "DojoKey" },
      { render.fit(#alts > 0 and table.concat(alts, "  ") or "–", 17) .. " ", "DojoDim" },
      stars,
    }
    if r.hint then
      row[#row + 1] = { "  hint", "DojoDim" }
    end
    if r.hints and r.hints[1] then
      row[#row + 1] = { "  " .. r.hints[1], "DojoDim" }
    end
    rows[#rows + 1] = row
  end
  rows[#rows + 1] = ""
  local keys
  if s.mode == "drill" then
    keys = " <CR> start the challenge   r drill again   m menu"
  elseif sum.pass and curriculum.next(s.id) then
    keys = " n next stage   r retry   m menu"
  else
    keys = " r retry   m menu"
  end
  rows[#rows + 1] = { { keys, "DojoDim" } }
  render.draw(buf, rows)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

return M
