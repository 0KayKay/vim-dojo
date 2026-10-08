local words = require("dojo.words")

-- ten lines long enough that a column up to 6 exists on every line
local function tall(rng)
  return words.lines(rng, 10, 4, 6)
end

return {
  key = "counts",
  title = "counts",
  name = "Repeat with a count",
  kind = "move",
  adds = { "count" },
  focus = { { "count" } },
  explainer = {
    heading = "Repeat a move with a count",
    keys = {
      { "4j", "four lines down" },
      { "3k", "three lines up" },
      { "3l", "three cells right (counts for single cells stop at 4)" },
    },
    example = {
      before = { "sun sky sea", "red map cup", "[o]wl box key" },
      keys = "2k",
      after = { "[s]un sky sea", "red map cup", "owl box key" },
    },
    combos = {
      { "3j2l", "down three lines, then two cells right" },
    },
    tip = "The relative numbers on the left are your counts: read the one next to the target line, type it, then j or k. From now on habit mode blocks a key pressed three times in a row in challenges (H in the menu).",
  },
  generate = function(rng, _)
    local lines = tall(rng)
    for _ = 1, 50 do
      local r = rng:int(1, #lines)
      local c = rng:int(0, 6)
      if rng:chance(0.7) then
        local r2 = r + (rng:chance(0.5) and 1 or -1) * rng:int(2, 8)
        if lines[r2] then
          return {
            kind = "move",
            lines = lines,
            cursor = { r, c },
            goal = { r2, c },
            prompt = "Move to the highlighted character",
          }
        end
      else
        local c2 = c + (rng:chance(0.5) and 1 or -1) * rng:int(2, 4)
        if c2 >= 0 and c2 < #lines[r] then
          return {
            kind = "move",
            lines = lines,
            cursor = { r, c },
            goal = { r, c2 },
            prompt = "Move to the highlighted character",
          }
        end
      end
    end
  end,
  -- both directions at once: 3j2l
  combined = function(rng, _)
    local lines = tall(rng)
    for _ = 1, 50 do
      local r, c = rng:int(1, #lines), rng:int(0, 6)
      local r2 = r + (rng:chance(0.5) and 1 or -1) * rng:int(2, 6)
      local c2 = c + (rng:chance(0.5) and 1 or -1) * rng:int(2, 4)
      if lines[r2] and c2 >= 0 and c2 < #lines[r2] then
        return {
          kind = "move",
          lines = lines,
          cursor = { r, c },
          goal = { r2, c2 },
          prompt = "Move to the highlighted character",
        }
      end
    end
  end,
}
