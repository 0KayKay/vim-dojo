-- Two-step rounds for challenges (SPEC §5): the target is on another line, so
-- a vertical and a horizontal move are needed.
local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "twostep",
  title = "two steps",
  name = "Two-step move",
  kind = "move",
  adds = {},
  focus = nil,
  generate = function(rng, ctx)
    local lines = words.lines(rng, 6, 6, 8)
    local r = rng:int(1, #lines)
    local sp = U.spans(lines[r])
    local c = sp[rng:int(1, #sp)].s
    local r2
    repeat
      r2 = rng:int(1, #lines)
    until r2 ~= r
    local tsp = U.spans(lines[r2])
    local options = {}
    for _, s in ipairs(tsp) do
      if ctx.learned.wb then
        options[#options + 1] = s.s
      end
      if ctx.learned.e then
        options[#options + 1] = s.e
      end
    end
    if ctx.learned.line then
      options[#options + 1] = #lines[r2] - 1
    end
    if #options == 0 then
      return nil
    end
    return {
      kind = "move",
      lines = lines,
      cursor = { r, c },
      goal = { r2, rng:pick(options) },
      prompt = "Move to the highlighted character",
    }
  end,
}
