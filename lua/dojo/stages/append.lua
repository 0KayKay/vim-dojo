local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  key = "append",
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
    combos = {
      { "jjA…", "on another line: go there, then append" },
      { "kI…", "up a line, then insert at its start" },
    },
    tip = "A and I work from anywhere on the line: only the line matters, not the column.",
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
    -- start mid-line, away from both ends, so A and I are the point
    local col = rng:int(math.min(4, #line - 1), math.max(math.min(4, #line - 1), #line - 5))
    return {
      kind = "edit",
      lines = { line },
      cursor = { 1, col },
      goal_lines = { goal },
      prompt = "Add the word shown in green",
    }
  end,
}
