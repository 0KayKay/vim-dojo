local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  key = "find",
  title = "f F",
  name = "Find a character",
  kind = "move",
  adds = { "f" },
  focus = { { "f" } },
  explainer = {
    heading = "Find a character on the line",
    keys = {
      { "f{char}", "forward onto the next {char}" },
      { "F{char}", "backward onto the previous {char}" },
    },
    example = {
      before = { "[c]all(alpha, beta);" },
      keys = "f,",
      after = { "call(alpha[,] beta);" },
    },
    combos = {
      { "df,", "delete up to and including the comma" },
      { "jf(", "down a line, then find" },
    },
    tip = "Look at the target, then type f and that character. Punctuation makes great targets. f is not always shortest: a word start is often just w away.",
  },
  generate = function(rng, _)
    local lines = { words.code_line(rng), words.code_line(rng), words.code_line(rng) }
    local row = 2
    local L = lines[row]
    for _ = 1, 60 do
      local col = rng:int(0, #L - 1)
      local dir = rng:chance(0.6) and 1 or -1
      local t = col + dir * rng:int(6, 40)
      if t >= 0 and t < #L then
        local ch = L:sub(t + 1, t + 1)
        local between = dir > 0 and L:sub(col + 2, t) or L:sub(t + 2, col)
        if ch ~= " " and not between:find(ch, 1, true) then
          return {
            kind = "move",
            lines = lines,
            cursor = { row, col },
            goal = { row, t },
            prompt = "Move to the highlighted character",
          }
        end
      end
    end
  end,
  -- with an operator (df,) most of the time; otherwise the generic combine step
  combined = function(rng, ctx)
    local kinds = {}
    if ctx.learned.d then
      kinds[#kinds + 1] = "df"
    end
    if ctx.learned.c then
      kinds[#kinds + 1] = "cf"
    end
    if #kinds > 0 and rng:chance(0.6) then
      return U.operator_to_punct(rng, kinds)
    end
  end,
}
