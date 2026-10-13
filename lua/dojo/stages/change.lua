local words = require("dojo.words")
local U = require("dojo.stages.util")

-- a replacement word that shares no first or last letter with the old one, so
-- that changing the whole word is the clear best answer
local function replacement(rng, old, avoid)
  for _ = 1, 200 do
    local w = rng:pick(words.list)
    if
      w ~= old
      and #w >= 3
      and #w <= 5
      and w:sub(1, 1) ~= old:sub(1, 1)
      and w:sub(-1) ~= old:sub(-1)
      and not vim.tbl_contains(avoid, w)
    then
      return w
    end
  end
end

return {
  key = "change",
  title = "c{motion}",
  name = "Change operator",
  kind = "edit",
  adds = { "c" },
  focus = { { "c" } },
  replacement = replacement,
  explainer = {
    heading = "Change: delete, then type",
    keys = {
      { "c{motion}", "delete like d, then start Insert mode" },
      { "cw  ce", "change to the end of the word" },
      { "c$", "change to the end of the line" },
    },
    example = {
      before = { "the [s]low fox" },
      keys = "cwquick<Esc>",
      after = { "the quic[k] fox" },
    },
    combos = {
      { "c2w cb c^", "every motion works, like with d" },
      { "2jcw…", "move first, then change" },
    },
    tip = "Watch out: cw acts like ce, so the space after the word survives. c saves a key over d followed by i.",
  },
  generate = function(rng, _)
    local ws = words.pick(rng, rng:int(6, 8), { min_len = 3 })
    local line = table.concat(ws, " ")
    local goal, col
    if rng:chance(0.6) then
      local i = rng:int(1, #ws)
      local new = replacement(rng, ws[i], ws)
      if not new then
        return nil
      end
      local g = U.copy(ws)
      g[i] = new
      goal, col = table.concat(g, " "), U.start_of(ws, i)
    else
      local i = rng:int(2, #ws)
      col = U.start_of(ws, i)
      local tail = words.pick(rng, rng:int(1, 2), { avoid = ws, max_len = 5 })
      goal = line:sub(1, col) .. table.concat(tail, " ")
      if goal:sub(col + 1, col + 1) == line:sub(col + 1, col + 1) then
        return nil -- same first letter would make a shorter answer
      end
    end
    return {
      kind = "edit",
      lines = { line },
      cursor = { 1, col },
      goal_lines = { goal },
      prompt = "Replace the struck-through text with the green text",
    }
  end,
}
