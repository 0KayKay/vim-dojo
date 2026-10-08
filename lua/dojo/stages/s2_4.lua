local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "2.4",
  title = "counts",
  name = "Repeat with a count",
  kind = "move",
  adds = { "count" },
  focus = { { "count" } },
  explainer = {
    heading = "Repeat a move with a count",
    keys = {
      { "4j", "four lines down" },
      { "3w", "three words forward" },
      { "3x", "delete three characters" },
    },
    example = {
      before = { "[o]ne two three four five" },
      keys = "3w",
      after = { "one two three [f]our five" },
    },
    tip = "The relative line numbers on the left are your counts for j and k. Estimate, then correct with a small move.",
  },
  generate = function(rng, _)
    local v = rng:pick({ "vertical", "vertical", "words", "x" })
    if v == "vertical" then
      local lines = words.lines(rng, 10, 4, 6)
      for _ = 1, 30 do
        local r = rng:int(1, #lines)
        local k = rng:int(3, 8)
        local r2 = rng:chance(0.5) and r + k or r - k
        local c = rng:int(0, 6)
        if lines[r2] then
          return {
            kind = "move",
            lines = lines,
            cursor = { r, c },
            goal = { r2, c },
            prompt = "Move to the highlighted character",
          }
        end
      end
    elseif v == "words" then
      local lines = words.lines(rng, 3, 10, 12)
      local sp = U.spans(lines[2])
      for _ = 1, 30 do
        local i = rng:int(1, #sp)
        local k = rng:int(3, 6)
        local j = rng:chance(0.6) and i + k or i - k
        if sp[j] then
          return {
            kind = "move",
            lines = lines,
            cursor = { 2, sp[i].s },
            goal = { 2, sp[j].s },
            prompt = "Move to the highlighted character",
          }
        end
      end
    else
      local line, goal, col = require("dojo.stages.s1_2").stray(rng, 3, 4)
      return {
        kind = "edit",
        lines = { line },
        cursor = { 1, col },
        goal_lines = { goal },
        prompt = "Delete the highlighted letters",
      }
    end
  end,
}
