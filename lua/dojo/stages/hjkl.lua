local words = require("dojo.words")

return {
  key = "hjkl",
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
    tip = "Rest your fingers on the home row: j points down, k points up. Pressing a key two or three times is fine; for longer trips, later stages bring better moves.",
  },
  generate = function(rng, ctx)
    local lines = words.lines(rng, 5, 6, 8)
    local far = ctx.learned.count
    for _ = 1, 50 do
      local r = rng:int(1, #lines)
      local c = rng:int(0, #lines[r] - 1)
      -- World 1: at most 3 lines and 3 cells, 4 presses in all; later, lines
      -- by count but still only a few cells sideways (h and l take no counts)
      local dr, dc
      if far then
        dr, dc = rng:int(-6, 6), rng:int(-3, 3)
      else
        dr, dc = rng:int(-3, 3), rng:int(-3, 3)
        if math.abs(dr) + math.abs(dc) > 4 then
          dr, dc = 0, 0
        end
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
