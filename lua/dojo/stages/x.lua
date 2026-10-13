local words = require("dojo.words")
local U = require("dojo.stages.util")

local JUNK = { "q", "z", "x", "j", "k", "v" }

-- A line with 1 or 2 stray letters stuck to the start or end of a word, where
-- a person would pluck them out (decision 0014). Returns the line, the goal
-- and the column of the first stray letter.
local function stray(rng, nmin, nmax)
  local ws = words.pick(rng, rng:int(5, 7))
  local wi = rng:int(1, #ws)
  local w = ws[wi]
  local at_end = rng:chance(0.6)
  local edge = at_end and w:sub(-1) or w:sub(1, 1)
  local junk = {}
  for i = 1, rng:int(nmin, nmax) do
    local c
    repeat
      c = rng:pick(JUNK)
    until c ~= edge and c ~= junk[i - 1]
    junk[i] = c
  end
  local bad = U.copy(ws)
  bad[wi] = at_end and (w .. table.concat(junk)) or (table.concat(junk) .. w)
  local col = U.start_of(bad, wi) + (at_end and #w or 0)
  return table.concat(bad, " "), table.concat(ws, " "), col
end

return {
  key = "x",
  title = "x",
  name = "Delete characters",
  kind = "edit",
  adds = { "x" },
  focus = { { "x" } },
  stray = stray,
  explainer = {
    heading = "Delete the character under the cursor",
    keys = {
      { "x", "delete one character" },
      { "u", "undo the last change (costs a key, like any key)" },
    },
    example = {
      before = { "the brown[q] fox" },
      keys = "x",
      after = { "the brow[n] fox" },
    },
    combos = {
      { "jlx", "go there first, then delete" },
      { "xx", "two stray letters in a row" },
    },
    tip = "Stray letters are struck through. Delete them all and the round ends. A slip? u undoes it.",
  },
  generate = function(rng, _)
    local line, goal, col = stray(rng, 1, 2)
    return {
      kind = "edit",
      lines = { line },
      cursor = { 1, col },
      goal_lines = { goal },
      prompt = "Delete the struck-through letters",
    }
  end,
}
