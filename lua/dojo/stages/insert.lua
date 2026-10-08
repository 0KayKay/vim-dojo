local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  key = "insert",
  title = "i a",
  name = "Insert text",
  kind = "edit",
  adds = { "ia" },
  focus = { { "ia" } },
  explainer = {
    heading = "Type text before or after the cursor",
    keys = {
      { "i", "insert before the cursor" },
      { "a", "append after the cursor" },
      { "<Esc>", "back to Normal mode (counts as a key)" },
    },
    example = {
      before = { "the [b]rown fox" },
      keys = "iquick␣<Esc>",
      after = { "the quick[ ]brown fox" },
    },
    combos = {
      { "2li…", "move a little first, then insert" },
      { "ja…", "from the line above: go down, then append" },
    },
    tip = "The goal line under the text shows what's missing. Type it, then <Esc>. i or a: pick the one that needs no extra move.",
  },
  generate = function(rng, _)
    local ws = words.pick(rng, rng:int(5, 7), { min_len = 3 })
    local goal = table.concat(ws, " ")
    local line, col
    if rng:chance(0.5) then
      -- a whole word is missing
      local j = rng:int(2, #ws - 1)
      local short = U.copy(ws)
      table.remove(short, j)
      line = table.concat(short, " ")
      if rng:chance(0.5) then
        col = U.start_of(short, j) -- i on the next word
      else
        col = U.start_of(short, j - 1) + #short[j - 1] - 1 -- a on the previous word
      end
    else
      -- one or two letters are missing inside a word
      local cands = {}
      for i, w in ipairs(ws) do
        if #w >= 4 then
          cands[#cands + 1] = i
        end
      end
      if #cands == 0 then
        return nil
      end
      local j = rng:pick(cands)
      local w = ws[j]
      local k = rng:int(1, 2)
      local p = rng:int(2, #w - k) -- first missing letter (1-based)
      local short = U.copy(ws)
      short[j] = w:sub(1, p - 1) .. w:sub(p + k)
      line = table.concat(short, " ")
      local base = U.start_of(short, j)
      if rng:chance(0.5) then
        col = base + p - 1 -- i on the letter after the gap
      else
        col = base + p - 2 -- a on the letter before the gap
      end
    end
    return {
      kind = "edit",
      lines = { line },
      cursor = { 1, col },
      goal_lines = { goal },
      prompt = "Type the missing text shown in the goal line",
    }
  end,
}
