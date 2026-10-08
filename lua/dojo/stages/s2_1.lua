local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "2.1",
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
    tip = "Count the word starts, not the letters.",
  },
  generate = function(rng, ctx)
    local lines = words.lines(rng, 3, 7, 9)
    local row = 2
    local sp = U.spans(lines[row])
    local maxk = ctx.learned.count and 6 or 4
    for _ = 1, 30 do
      local i = rng:int(1, #sp)
      local k = rng:int(1, maxk)
      local j = rng:chance(0.5) and i + k or i - k
      if sp[j] then
        local col = sp[i].s
        if ctx.mode == "challenge" and rng:chance(0.3) then
          col = rng:int(sp[i].s, sp[i].e) -- start inside a word
        end
        return {
          kind = "move",
          lines = lines,
          cursor = { row, col },
          goal = { row, sp[j].s },
          prompt = "Move to the highlighted character",
        }
      end
    end
  end,
}
