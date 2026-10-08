local words = require("dojo.words")

return {
  key = "lines",
  title = "dd cc",
  name = "Whole lines",
  kind = "edit",
  adds = { "lines" },
  focus = { { "lines" } },
  explainer = {
    heading = "Work on whole lines",
    keys = {
      { "dd", "delete the line" },
      { "3dd", "delete three lines, starting here" },
      { "dj  dk", "delete this line and the next / previous one" },
      { "cc", "rewrite the line: delete it, then type" },
    },
    example = {
      before = { "keep this", "[d]rop this", "keep that" },
      keys = "dd",
      after = { "keep this", "[k]eep that" },
    },
    combos = {
      { "d2j", "j and k make any operator work on whole lines" },
      { "2jdd", "go to the line first" },
      { "kcc…", "rewrite the line above" },
    },
    tip = "Doubling an operator (dd, cc) applies it to the whole line, wherever the cursor is on it.",
  },
  generate = function(rng, ctx)
    local lines = words.lines(rng, 7, 3, 6)
    if rng:chance(0.35) then
      -- rewrite one line with cc
      local r = rng:int(1, #lines)
      local new = table.concat(words.pick(rng, rng:int(1, 2), { max_len = 5 }), " ")
      if new:sub(1, 1) == lines[r]:sub(1, 1) then
        return nil
      end
      local goal = vim.deepcopy(lines)
      goal[r] = new
      return {
        kind = "edit",
        lines = lines,
        cursor = { r, rng:int(1, #lines[r] - 1) },
        goal_lines = goal,
        prompt = "Rewrite the highlighted line to match the goal",
      }
    end
    local k = rng:int(1, 4)
    local r = rng:int(1, #lines - k + 1)
    local goal = {}
    for i, l in ipairs(lines) do
      if i < r or i >= r + k then
        goal[#goal + 1] = l
      end
    end
    -- start on the first or the last of the lines (dk deletes upward)
    local row = (k == 2 and ctx.learned.hjkl and rng:chance(0.3)) and (r + 1) or r
    return {
      kind = "edit",
      lines = lines,
      cursor = { row, rng:int(0, #lines[row] - 1) },
      goal_lines = goal,
      prompt = "Delete the highlighted lines",
    }
  end,
}
