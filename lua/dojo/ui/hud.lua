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

  local title = string.format(" %s %s · %s", s.stage.id, s.stage.title, s.mode == "drill" and "Drill" or "Challenge")
  local right, time_text, time_hl = "", "", "DojoDim"
  if r then
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
    { { " " .. (r and r.task.prompt or "") } },
    { { " Learned: " .. moves.learned_label(s.learned), "DojoDim" } },
    s.last or { { "" } },
  }
  render.draw(buf, rows)
end

function M.round(s, r)
  draw(s, r, 0)
end

function M.tick(s, r, elapsed)
  draw(s, r, elapsed)
end

function M.countdown(s, n)
  s.last = { { string.format(" Get ready… %d", n), "DojoWarn" } }
  draw(s, nil)
end

function M.hint(s, r)
  local msg = s.mode == "challenge" and "   (this round can now earn 1 star at most)" or ""
  s.last = { { " Hint: ", "DojoDim" }, { r.sol.display, "DojoKey" }, { msg, "DojoDim" } }
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

-- the result of a finished round, shown during the pause and the next round
function M.result(s, r)
  local segs = {}
  if r.solved then
    segs[#segs + 1] = { " ✓ ", "DojoOk" }
    segs[#segs + 1] = { string.format("%d %s · par %d", r.count, r.count == 1 and "key" or "keys", r.par) }
    segs[#segs + 1] = { " · " }
    segs[#segs + 1] = { score.stars_text(r.stars), "DojoStar" }
    if r.count < r.par and not r.hint then
      segs[#segs + 1] = { " under par!", "DojoOk" }
    end
  else
    segs[#segs + 1] = { " ✗ time out", "DojoBad" }
  end
  if r.count ~= r.par or not r.solved then
    segs[#segs + 1] = { " · intended " }
    segs[#segs + 1] = { r.sol.display, "DojoKey" }
  end
  if r.hints and r.hints[1] then
    segs[#segs + 1] = { " · tip: " .. r.hints[1], "DojoDim" }
  end
  s.last = segs
  draw(s, r, r.time_ms)
end

return M
