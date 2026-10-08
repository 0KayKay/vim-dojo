local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  key = "till",
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
    combos = {
      { "dt,", "delete up to the comma, keep it" },
      { "ct)", "change everything up to the parenthesis" },
      { "kt;", "up a line, then till" },
    },
    tip = "t is made for operators: read dt, as 'delete till comma'. Which move when: lines with a count and j k, a few cells with h l, words with w b e, line edges with 0 ^ $, one specific character with f or t.",
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
  -- with an operator (dt, ct)) most of the time; otherwise the generic combine step
  combined = function(rng, ctx)
    local kinds = {}
    if ctx.learned.d then
      kinds[#kinds + 1] = "dt"
    end
    if ctx.learned.c then
      kinds[#kinds + 1] = "ct"
    end
    if #kinds > 0 and rng:chance(0.6) then
      return U.operator_to_punct(rng, kinds)
    end
  end,
}
