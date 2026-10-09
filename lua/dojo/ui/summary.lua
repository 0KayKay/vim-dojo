-- After every drill, challenge and boss: every round, your keys vs. the
-- intended solution, and for bosses the concept report (SPEC.md §8 Summary).
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local curriculum = require("dojo.curriculum")
local score = require("dojo.score")
local moves = require("dojo.moves")
local config = require("dojo.config")

local M = {}

local last -- { s, sum, newbest }
local mapped -- the buffer that has our keymaps (it can be wiped and recreated)
local round_line, line_round = {}, {} -- round index <-> buffer row

local function selected_round()
  return line_round[vim.api.nvim_win_get_cursor(0)[1]]
end

-- j/k step between round rows (SPEC §8 Summary)
local function step(dir)
  local i = selected_round()
  local n = #last.s.rounds
  local target = i and math.max(1, math.min(n, i + dir)) or 1
  if round_line[target] then
    vim.api.nvim_win_set_cursor(0, { round_line[target], 0 })
  end
end

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
  -- look at a round as it started, and play it again (decision 0017)
  vim.keymap.set("n", "<CR>", function()
    local i = selected_round()
    if i then
      require("dojo.ui.review").show(last.s, i)
    end
  end, o)
  for _, k in ipairs({ "j", "<Down>" }) do
    vim.keymap.set("n", k, function()
      step(1)
    end, o)
  end
  for _, k in ipairs({ "k", "<Up>" }) do
    vim.keymap.set("n", k, function()
      step(-1)
    end, o)
  end
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

-- the summary shown last, again (back from a round review), cursor on round i
function M.reshow(i)
  if last then
    M.show(last.s, last.sum, last.newbest, i)
  end
end

function M.show(s, sum, newbest, focus_round)
  last = { s = s, sum = sum, newbest = newbest }
  local keys
  if s.mode == "drill" then
    keys = " <CR> look at round   n start the challenge   r drill again   m menu"
  elseif sum.pass and curriculum.next(s.id) then
    keys = s.mode == "boss" and " <CR> look at round   n next world   r retry   m menu"
      or " <CR> look at round   n next stage   r retry   m menu"
  else
    keys = " <CR> look at round   r retry   m menu"
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
  round_line, line_round = {}, {}
  local timed_out = false
  for i, r in ipairs(s.rounds) do
    timed_out = timed_out or not r.solved
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
    round_line[i], line_round[#rows] = #rows, i
  end
  -- after a timeout: undo saves a round from a slip (decision 0017); in a boss
  -- summary this line takes the place of the gap before the concept report
  if timed_out then
    rows[#rows + 1] = { { " A slip? ", "DojoWarn" }, { "u", "DojoKey" }, { " undoes it for one key, and the round goes on.", "DojoDim" } }
  end
  if s.mode == "boss" then
    -- three columns, so every move family fits on an 80 × 24 screen
    local list, weakest = score.concept_report(s.rounds)
    if not timed_out then
      rows[#rows + 1] = ""
    end
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
  vim.api.nvim_win_set_cursor(win, { round_line[focus_round or 1] or 1, 0 })
end

return M
