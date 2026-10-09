-- Look at a finished round as it started, and play it again without a clock
-- (SPEC.md §8 Review, docs/decisions/0017). Nothing here is scored or saved.
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local score = require("dojo.score")
local round = require("dojo.round")

local M = {}

local cur -- { s = session, i = round index, try = result of the last replay }
local mapped -- the buffer that has our keymaps (it can be wiped and recreated)

local function keys_of(res)
  local parts = {}
  for _, k in ipairs(res and res.keys or {}) do
    parts[#parts + 1] = k.k
  end
  return table.concat(parts)
end

-- cut long keys short, but don't pad short ones
local function clip(s, w)
  return render.width(s) <= w and s or render.fit(s, w)
end

local function back()
  layout.close_hud()
  local i = cur and cur.i
  require("dojo.ui.summary").reshow(i)
end

local function map(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "p", function()
    M.practice()
  end, o)
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, back, o)
  end
  vim.keymap.set("n", "m", function()
    layout.close_hud()
    require("dojo.ui.menu").show(cur and cur.s.id)
  end, o)
end

local mode_name = { drill = "Drill", challenge = "Challenge" }

local function header(s, i, r)
  local width = layout.hud_width()
  local what = s.mode == "boss" and string.format("World %d boss", s.stage.world)
    or string.format("%s · %s", s.stage.title, mode_name[s.mode])
  local title = string.format(" %s %s · round %d of %d", s.stage.id, what, i, #s.rounds)
  local right = string.format("seed %d ", r.task.seed or s.seed)
  local prompt = r.task.steps and string.format("A chain of %d steps, done in order", #r.task.steps) or r.task.prompt
  local you
  if r.solved then
    you = {
      { " You: " },
      { clip(keys_of(r.result), 24), "DojoKey" },
      { string.format("  %d %s ", r.count, r.count == 1 and "key" or "keys") },
      { score.stars_text(r.stars), "DojoStar" },
    }
  else
    you = { { " You: " }, { clip(keys_of(r.result), 24), "DojoKey" }, { "  time out", "DojoBad" } }
  end
  you[#you + 1] = { string.format(" · par %d: ", r.par) }
  you[#you + 1] = { r.sol.display, "DojoKey" }
  if r.alts and r.alts[1] then
    local alts = {}
    for k = 1, math.min(2, #r.alts) do
      alts[#alts + 1] = r.alts[k].display
    end
    you[#you + 1] = { " · also " }
    you[#you + 1] = { table.concat(alts, ", "), "DojoKey" }
  end
  local last = { { "" } }
  if cur.try then
    local t = cur.try
    if t.solved then
      last = {
        { " Again: ", "DojoDim" },
        { "✓ ", "DojoOk" },
        { keys_of(t), "DojoKey" },
        { string.format("  %d %s ", t.count, t.count == 1 and "key" or "keys") },
        { score.stars_text(score.round_stars(t, r.par)), "DojoStar" },
      }
    end
  end
  return {
    { { title, "DojoTitle" }, { string.rep(" ", math.max(1, width - render.width(title) - render.width(right))) }, { right, "DojoDim" } },
    { { " " .. prompt } },
    you,
    last,
  }
end

-- s: the finished session (drill, challenge or boss), i: round index
function M.show(s, i)
  if not cur or cur.s ~= s or cur.i ~= i then
    cur = { s = s, i = i }
  end
  local r = s.rounds[i]
  local buf, win = layout.show("review", { play = true, status = " p play it again   q back to the summary" })
  if mapped ~= buf then
    map(buf)
    mapped = buf
  end
  round.load(buf, win, r.task)
  vim.bo[buf].modifiable = false
  require("dojo.ui.hud").custom(header(s, i, r))
end

-- the same round again in the play buffer: untimed, no habit mode, not saved
function M.practice()
  local s, i = cur.s, cur.i
  local r = s.rounds[i]
  local hud = require("dojo.ui.hud")
  local buf, win = layout.show("play", { play = true, status = " <Tab> hint   :q back to the review" })
  if vim.api.nvim_get_current_win() ~= win then
    vim.api.nvim_set_current_win(win)
  end
  cur.playing = true
  local ps = { stage = s.stage, mode = "practice", learned = s.learned, plan = s.rounds }
  local pr = { index = i, task = r.task, sol = r.sol, step = 1, variant = r.variant }
  hud.round(ps, pr)
  round.start({
    buf = buf,
    win = win,
    task = vim.deepcopy(r.task),
    habit = false,
    on_done = function(res)
      if not cur or cur.s ~= s then
        return
      end
      cur.try = res
      cur.playing = false
      vim.defer_fn(function()
        -- only if the player is still looking at the replay
        local w = layout.main_win()
        if cur and cur.s == s and w and vim.api.nvim_win_get_buf(w) == buf then
          M.show(s, i)
        end
      end, 600)
    end,
    on_tick = function(elapsed)
      pr.elapsed = elapsed
      hud.tick(ps, pr, elapsed)
    end,
    on_step = function(step)
      pr.step = step
      hud.tick(ps, pr, pr.elapsed)
    end,
    on_hint = function()
      hud.hint(ps, pr)
    end,
    on_blocked = function() end,
  })
end

-- is a replay running? (for :q and leaving the tab, which return here)
function M.replaying()
  return cur ~= nil and cur.playing == true and round.is_active()
end

-- back to the review after a replay was stopped
function M.resume()
  if cur then
    cur.playing = false
    M.show(cur.s, cur.i)
  end
end

-- for tests: the round on screen
function M._round()
  return cur and cur.s.rounds[cur.i]
end

return M
