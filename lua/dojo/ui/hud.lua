-- The header above the play buffer (SPEC.md §8 Round).
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local moves = require("dojo.moves")
local score = require("dojo.score")
local config = require("dojo.config")

local M = {}

-- s: session, r: round (may be nil during the countdown)
local function draw(s, r, elapsed)
  layout.open_hud()
  local buf = layout.buf("hud")
  local width = layout.hud_width()
  local cfg = config.get()

  local part = ({ drill = "Drill", challenge = "Challenge", boss = "World " .. s.stage.world, practice = "Practice" })[s.mode]
  if r and s.mode == "drill" then
    part = r.variant == "combined" and "Drill · combined" or "Drill · basics"
  elseif r and s.mode == "boss" then
    part = r.variant == "chain" and "chain" or "mixed"
  end
  local title = string.format(" %s %s · %s", s.stage.id, s.stage.title, part)
  local right, time_text, time_hl = "", "", "DojoDim"
  local prompt = r and r.task.prompt or ""
  if r then
    local steps = r.task.steps
    if steps then
      local st = steps[r.step or 1]
      prompt = string.format("Step %d/%d: %s", r.step or 1, #steps, st.prompt)
    end
    right = string.format("round %d/%d   par %d   ", r.index, #s.plan, r.sol.cost)
    if r.limit_ms then
      local left = math.max(0, (r.limit_ms - (elapsed or 0)) / 1000)
      time_text = string.format("%4.1f s left", left)
      time_hl = left <= cfg.warn_s and "DojoWarn" or "DojoKey"
    else
      time_text = "no clock"
    end
  end
  local used = render.width(title) + render.width(right) + render.width(time_text) + 1
  local pad = string.rep(" ", math.max(1, width - used))

  local rows = {
    { { title, "DojoTitle" }, { pad }, { right }, { time_text, time_hl } },
    { { " " .. prompt } },
    { { " Learned: " .. moves.learned_label(s.learned), "DojoDim" } },
    s.last or { { "" } },
  }
  render.draw(buf, rows)
end

function M.round(s, r)
  draw(s, r, 0)
end

-- any rows, for screens that borrow the header (the round review)
function M.custom(rows)
  layout.open_hud()
  render.draw(layout.buf("hud"), rows)
end

function M.tick(s, r, elapsed)
  draw(s, r, elapsed)
end

function M.countdown(s, n)
  s.last = { { string.format(" Get ready… %d", n), "DojoWarn" } }
  draw(s, nil)
end

function M.hint(s, r)
  local msg = s.mode ~= "drill" and "   (this round can now earn 1 star at most)" or ""
  local display = r.sol.display
  if r.task.steps then
    display = r.task.steps[r.step or 1].sol.display -- this step only
  end
  s.last = { { " Hint: ", "DojoDim" }, { display, "DojoKey" }, { msg, "DojoDim" } }
  draw(s, r, r.elapsed)
end

function M.blocked(s, r, key)
  s.last = {
    { " Habit mode: ", "DojoWarn" },
    { key .. key .. key, "DojoKey" },
    { " blocked. Try a count, like ", "DojoDim" },
    { "3" .. key, "DojoKey" },
  }
  draw(s, r, r.elapsed)
end

-- the result of a finished round, shown during the pause and the next round:
-- your keys, the intended solution and alternatives (SPEC §6 Feedback)
function M.result(s, r)
  local mine = {}
  for _, k in ipairs(r.result and r.result.keys or {}) do
    mine[#mine + 1] = k.k
  end
  local segs = {}
  if r.solved then
    segs[#segs + 1] = { " ✓ ", "DojoOk" }
    segs[#segs + 1] = { score.stars_text(r.stars), "DojoStar" }
    segs[#segs + 1] = { string.format(" %d %s", r.count, r.count == 1 and "key" or "keys") }
    if r.count < r.par and not r.hint then
      segs[#segs + 1] = { " under par!", "DojoOk" }
    end
    segs[#segs + 1] = { " · you " }
    segs[#segs + 1] = { render.fit(table.concat(mine), math.min(14, math.max(1, render.width(table.concat(mine))))) }
  else
    segs[#segs + 1] = { " ✗ time out", "DojoBad" }
  end
  segs[#segs + 1] = { string.format(" · par %d: ", r.par) }
  segs[#segs + 1] = { r.sol.display, "DojoKey" }
  if r.alts and r.alts[1] then
    local alts = {}
    for i = 1, math.min(2, #r.alts) do
      alts[#alts + 1] = r.alts[i].display
    end
    segs[#segs + 1] = { " · also " }
    segs[#segs + 1] = { table.concat(alts, ", "), "DojoKey" }
  end
  if r.hints and r.hints[1] then
    segs[#segs + 1] = { " · tip: " .. r.hints[1], "DojoDim" }
  end
  s.last = segs
  draw(s, r, r.time_ms)
end

return M
