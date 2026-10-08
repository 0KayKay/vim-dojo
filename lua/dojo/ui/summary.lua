-- After every drill, challenge and boss: every round, your keys vs. the
-- intended solution, and for bosses the concept report (SPEC.md §8 Summary).
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local curriculum = require("dojo.curriculum")
local score = require("dojo.score")
local moves = require("dojo.moves")
local config = require("dojo.config")

local M = {}

local last -- { s, sum }
local mapped -- the buffer that has our keymaps (it can be wiped and recreated)

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

local mode_name = { drill = "Drill", challenge = "Challenge", boss = "Boss" }

function M.show(s, sum, newbest)
  last = { s = s, sum = sum }
  local keys
  if s.mode == "drill" then
    keys = " <CR> start the challenge   r drill again   m menu"
  elseif sum.pass and curriculum.next(s.id) then
    keys = s.mode == "boss" and " n next world   r retry   m menu" or " n next stage   r retry   m menu"
  else
    keys = " r retry   m menu"
  end
  local buf, win = layout.show("summary", { status = keys })
  if mapped ~= buf then
    map(buf)
    mapped = buf
  end
  local width = vim.api.nvim_win_get_width(win)
  local head = s.mode == "boss" and string.format(" %s World %d boss complete", s.stage.id, s.stage.world)
    or string.format(" %s %s · %s complete", s.stage.id, s.stage.title, mode_name[s.mode])
  local right = s.mode ~= "drill" and string.format("%s   score %.2f ", score.stars_text(sum.stars), sum.score) or ""
  local rows = {
    {
      { head, "DojoTitle" },
      { string.rep(" ", math.max(1, width - render.width(head) - render.width(right))) },
      { right, "DojoStar" },
    },
  }
  local line = {
    {
      string.format(
        " Solved %d/%d · at par %d/%d · average %.1f s · seed %d",
        sum.solved,
        sum.rounds,
        sum.at_par,
        sum.rounds,
        sum.avg_time_s,
        s.seed
      ),
    },
  }
  if newbest then
    line[#line + 1] = { "   new best!", "DojoOk" }
  end
  if s.mode ~= "drill" and not sum.pass then
    local need = math.ceil(config.get().pass_ratio * sum.rounds - 1e-9)
    line[#line + 1] = { string.format("   solve %d of %d to pass", need, sum.rounds), "DojoWarn" }
  end
  rows[#rows + 1] = line
  rows[#rows + 1] = ""
  rows[#rows + 1] = {
    {
      "  #  "
        .. render.fit("your keys", 16)
        .. render.fit("par", 5)
        .. render.fit("intended", 15)
        .. render.fit("also works", 18)
        .. "stars",
      "DojoDim",
    },
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
    }
    if r.variant == "chain" then
      -- chains have no alternatives: the steps get both columns
      row[#row + 1] = { render.fit(r.sol.display, 32) .. " ", "DojoKey" }
    else
      row[#row + 1] = { render.fit(r.sol.display, 14) .. " ", "DojoKey" }
      row[#row + 1] = { render.fit(#alts > 0 and table.concat(alts, "  ") or "–", 17) .. " ", "DojoDim" }
    end
    row[#row + 1] = stars
    if r.hint then
      row[#row + 1] = { "  hint", "DojoDim" }
    end
    if r.hints and r.hints[1] then
      row[#row + 1] = { "  " .. r.hints[1], "DojoDim" }
    end
    rows[#rows + 1] = row
  end
  if s.mode == "boss" then
    -- three columns, so every move family fits on an 80 × 24 screen
    local list, weakest = score.concept_report(s.rounds)
    rows[#rows + 1] = ""
    rows[#rows + 1] = { { " By move: rounds that used it, average stars", "DojoDim" } }
    local row
    for i, st in ipairs(list) do
      if (i - 1) % 3 == 0 then
        row = { { " " } }
        rows[#rows + 1] = row
      end
      local hl = (weakest and st.fam == weakest.fam) and "DojoWarn" or nil
      row[#row + 1] = { render.fit(moves.labels[st.fam] or st.fam, 8), hl }
      row[#row + 1] = { render.fit(tostring(st.n), 3), "DojoDim" }
      row[#row + 1] = { score.stars_text(math.floor(st.avg + 0.5)), "DojoStar" }
      row[#row + 1] = { render.fit(string.format(" %.1f", st.avg), 9), "DojoDim" }
    end
    if weakest then
      local teach = curriculum.stage_for_family(weakest.fam)
      rows[#rows + 1] = {
        { " Weakest: ", "DojoWarn" },
        { moves.labels[weakest.fam] or weakest.fam, "DojoKey" },
        { teach and string.format("  replay %s %s to sharpen it", teach.id, teach.title) or "", "DojoWarn" },
      }
    else
      rows[#rows + 1] = { { " Every move at par. Nothing to sharpen.", "DojoOk" } }
    end
  end
  render.draw(buf, rows)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

return M
