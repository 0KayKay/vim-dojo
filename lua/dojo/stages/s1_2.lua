local words = require("dojo.words")
local U = require("dojo.stages.util")

local JUNK = { "q", "z", "x", "j", "k", "v" }

-- A line with a run of stray letters inside one word.
local function stray(rng, nmin, nmax)
  local ws = words.pick(rng, rng:int(5, 7))
  local wi = rng:int(1, #ws)
  local w = ws[wi]
  local pos = rng:int(1, #w) -- stray letters go after this many letters
  local prev, nxt = w:sub(pos, pos), w:sub(pos + 1, pos + 1)
  local junk = {}
  for i = 1, rng:int(nmin, nmax) do
    local c
    repeat
      c = rng:pick(JUNK)
    until c ~= prev and c ~= nxt and c ~= junk[i - 1]
    junk[i] = c
  end
  local bad = U.copy(ws)
  bad[wi] = w:sub(1, pos) .. table.concat(junk) .. w:sub(pos + 1)
  local col = U.start_of(bad, wi) + pos
  return table.concat(bad, " "), table.concat(ws, " "), col
end

return {
  id = "1.2",
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
      before = { "the bro[q]wn fox" },
      keys = "x",
      after = { "the bro[w]n fox" },
    },
    tip = "Stray letters are highlighted. Delete them all and the round ends.",
  },
  generate = function(rng, ctx)
    local line, goal, col = stray(rng, 1, 3)
    col = U.maybe_wander(rng, ctx, col, line)
    return {
      kind = "edit",
      lines = { line },
      cursor = { 1, col },
      goal_lines = { goal },
      prompt = "Delete the highlighted letters",
    }
  end,
}
