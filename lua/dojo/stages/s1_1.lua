local words = require("dojo.words")

return {
  id = "1.1",
  title = "h j k l",
  name = "Move by cells",
  kind = "move",
  adds = { "hjkl" },
  focus = { { "hjkl" } },
  explainer = {
    heading = "Move one cell at a time",
    keys = {
      { "h", "left" },
      { "j", "down" },
      { "k", "up" },
      { "l", "right" },
    },
    example = {
      before = { "sun [s]ky sea", "red map cup" },
      keys = "jl",
      after = { "sun sky sea", "red m[a]p cup" },
    },
    tip = "Rest your fingers on the home row: j points down, k points up.",
  },
  generate = function(rng, ctx)
    local lines = words.lines(rng, 5, 6, 8)
    local far = ctx.learned.count
    for _ = 1, 50 do
      local r = rng:int(1, #lines)
      local c = rng:int(0, #lines[r] - 1)
      local dr, dc
      if far then
        dr, dc = rng:int(-6, 6), rng:int(-3, 3)
      else
        dr = rng:int(-3, 3)
        local room = 3 - math.abs(dr)
        dc = rng:int(-room, room)
      end
      local tr, tc = r + dr, c + dc
      if (dr ~= 0 or dc ~= 0) and lines[tr] and tc >= 0 and tc < #lines[tr] then
        return {
          kind = "move",
          lines = lines,
          cursor = { r, c },
          goal = { tr, tc },
          prompt = "Move to the highlighted character",
        }
      end
    end
  end,
}
