local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "4.2",
  title = "t T",
  name = "Till a character",
  kind = "move",
  adds = { "t" },
  focus = { { "t" } },
  explainer = {
    heading = "Stop just before a character",
    keys = {
      { "t{char}", "forward, stopping one cell before {char}" },
      { "T{char}", "backward, stopping one cell after {char}" },
    },
    example = {
      before = { "[c]all(alpha, beta);" },
      keys = "t(",
      after = { "cal[l](alpha, beta);" },
    },
    tip = "t is made for operators: dt, will delete up to a comma and keep the comma.",
  },
  generate = function(rng, _)
    local lines = { words.code_line(rng), words.code_line(rng), words.code_line(rng) }
    local row = 2
    local L = lines[row]
    for _ = 1, 60 do
      local col = rng:int(0, #L - 1)
      local p = rng:int(0, #L - 1) -- position of the punctuation mark
      local ch = L:sub(p + 1, p + 1)
      if U.is_punct(ch) then
        if p >= col + 4 and not L:sub(col + 2, p):find(ch, 1, true) then
          return {
            kind = "move",
            lines = lines,
            cursor = { row, col },
            goal = { row, p - 1 },
            prompt = "Move to the highlighted character",
          }
        elseif p <= col - 4 and not L:sub(p + 2, col):find(ch, 1, true) then
          return {
            kind = "move",
            lines = lines,
            cursor = { row, col },
            goal = { row, p + 1 },
            prompt = "Move to the highlighted character",
          }
        end
      end
    end
  end,
}
