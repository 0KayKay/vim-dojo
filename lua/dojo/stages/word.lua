local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  key = "word",
  title = "w b",
  name = "Jump by words",
  kind = "move",
  adds = { "wb" },
  focus = { { "wb" } },
  explainer = {
    heading = "Jump by words",
    keys = {
      { "w", "forward to the start of the next word" },
      { "b", "back to the start of the previous word (or of this one)" },
    },
    example = {
      before = { "[t]he quick brown fox jumps" },
      keys = "ww",
      after = { "the quick [b]rown fox jumps" },
    },
    combos = {
      { "3w", "with counts: three words" },
      { "2j3w", "down two lines, then three words" },
    },
    tip = "Count the word starts, not the letters. Targets are never more than 4 words away.",
  },
  generate = function(rng, _)
    local lines = words.lines(rng, 3, 7, 9)
    local row = 2
    local sp = U.spans(lines[row])
    for _ = 1, 30 do
      local i = rng:int(1, #sp)
      local k = rng:int(1, 4)
      local j = rng:chance(0.5) and i + k or i - k
      if sp[j] then
        return {
          kind = "move",
          lines = lines,
          cursor = { row, sp[i].s },
          goal = { row, sp[j].s },
          prompt = "Move to the highlighted character",
        }
      end
    end
  end,
}
