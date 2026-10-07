local words = require("dojo.words")

return {
  id = "3.2",
  title = "dd",
  name = "Delete lines",
  kind = "edit",
  adds = { "dd" },
  focus = { { "dd" } },
  explainer = {
    heading = "Delete whole lines",
    keys = {
      { "dd", "delete the current line" },
      { "3dd", "delete three lines, starting here" },
    },
    example = {
      before = { "keep this", "[d]rop this", "keep that" },
      keys = "dd",
      after = { "keep this", "[k]eep that" },
    },
    tip = "Doubling an operator applies it to the whole line. dj also deletes two lines.",
  },
  generate = function(rng, ctx)
    local lines = words.lines(rng, 7, 3, 6)
    -- two lines is cheaper as dj, so drills use 1, 3 or 4
    local k = ctx.mode == "drill" and rng:pick({ 1, 3, 4 }) or rng:int(1, 4)
    local r = rng:int(1, #lines - k + 1)
    local goal = {}
    for i, l in ipairs(lines) do
      if i < r or i >= r + k then
        goal[#goal + 1] = l
      end
    end
    local row = r
    if ctx.mode == "challenge" and rng:chance(0.3) then
      row = math.max(1, math.min(#lines, r + rng:pick({ -2, -1, 1, 2 })))
    end
    return {
      kind = "edit",
      lines = lines,
      cursor = { row, rng:int(0, #lines[row] - 1) },
      goal_lines = goal,
      prompt = "Delete the highlighted lines",
    }
  end,
}
