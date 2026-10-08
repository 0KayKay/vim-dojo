local words = require("dojo.words")

return {
  id = "2.3",
  title = "0 ^ $",
  name = "Line edges",
  kind = "move",
  adds = { "line" },
  focus = { { "line" } },
  explainer = {
    heading = "Jump to the edges of the line",
    keys = {
      { "0", "the first column" },
      { "^", "the first non-blank character" },
      { "$", "the last character" },
    },
    example = {
      before = { "    if the [w]ind is calm" },
      keys = "^",
      after = { "    [i]f the wind is calm" },
    },
    tip = "On indented lines 0 and ^ differ: ^ skips the indentation.",
  },
  generate = function(rng, _)
    local lines = words.lines(rng, 3, 6, 8)
    local row = 2
    local indent = rng:chance(0.6) and rng:int(2, 6) or 0
    lines[row] = string.rep(" ", indent) .. lines[row]
    local line = lines[row]
    local kinds = indent > 0 and { "0", "^", "$" } or { "0", "$" }
    local kind = rng:pick(kinds)
    local target = (kind == "0" and 0) or (kind == "^" and indent) or (#line - 1)
    local col = rng:int(indent + 3, #line - 4)
    return {
      kind = "move",
      lines = lines,
      cursor = { row, col },
      goal = { row, target },
      prompt = "Move to the highlighted character",
    }
  end,
}
