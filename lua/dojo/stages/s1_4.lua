local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "1.4",
  title = "A I",
  name = "Add at line ends",
  kind = "edit",
  adds = { "AI" },
  focus = { { "AI" } },
  explainer = {
    heading = "Add text at the ends of the line",
    keys = {
      { "A", "append at the end of the line" },
      { "I", "insert before the first non-blank character" },
    },
    example = {
      before = { "the quick [b]rown" },
      keys = "A␣fox<Esc>",
      after = { "the quick brown fo[x]" },
    },
    tip = "A and I work from anywhere on the line: no need to move first.",
  },
  generate = function(rng, _)
    local ws = words.pick(rng, rng:int(5, 7))
    local goal = table.concat(ws, " ")
    local short = U.copy(ws)
    if rng:chance(0.5) then
      table.remove(short) -- last word missing: A
    else
      table.remove(short, 1) -- first word missing: I
    end
    local line = table.concat(short, " ")
    return {
      kind = "edit",
      lines = { line },
      cursor = { 1, rng:int(0, #line - 1) },
      goal_lines = { goal },
      prompt = "Add the missing word shown in the goal line",
    }
  end,
}
