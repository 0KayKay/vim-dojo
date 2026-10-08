local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "2.2",
  title = "e",
  name = "Word ends",
  kind = "move",
  adds = { "e" },
  focus = { { "e" } },
  explainer = {
    heading = "Jump to the end of a word",
    keys = {
      { "e", "forward to the end of the word (the next one if you're already there)" },
    },
    example = {
      before = { "[t]he quick brown fox" },
      keys = "ee",
      after = { "the quic[k] brown fox" },
    },
    tip = "w lands on the start of a word, e on its end. Use whichever is closer to the target.",
  },
  generate = function(rng, ctx)
    local lines = words.lines(rng, 3, 7, 9)
    local row = 2
    local sp = U.spans(lines[row])
    local maxk = ctx.learned.count and 5 or 4
    for _ = 1, 30 do
      local i = rng:int(1, #sp)
      local k = rng:int(1, maxk)
      local j = i + k - 1
      if sp[j] then
        return {
          kind = "move",
          lines = lines,
          cursor = { row, sp[i].s },
          goal = { row, sp[j].e },
          prompt = "Move to the highlighted character",
        }
      end
    end
  end,
}
