local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "3.1",
  title = "d{motion}",
  name = "Delete operator",
  kind = "edit",
  adds = { "d" },
  focus = { { "d" } },
  explainer = {
    heading = "Delete with an operator",
    keys = {
      { "d{motion}", "delete from the cursor to where the motion goes" },
      { "dw", "to the start of the next word" },
      { "de", "to the end of the word" },
      { "d$  d0", "to the end / start of the line" },
      { "d2w", "a count works too: two words" },
    },
    example = {
      before = { "the [q]uick brown fox" },
      keys = "dw",
      after = { "the [b]rown fox" },
    },
    tip = "Operator + motion is Vim's grammar: every motion you know is now something you can delete.",
  },
  generate = function(rng, ctx)
    local ws = words.pick(rng, rng:int(6, 9))
    local line = table.concat(ws, " ")
    local sp = U.spans(line)
    local kinds = { "dw", "de", "d$", "d0", "db" }
    if ctx.learned.count then
      kinds[#kinds + 1] = "d2w"
    end
    local kind = rng:pick(kinds)
    local s, e, col -- delete [s, e), cursor col
    if kind == "dw" then
      local i = rng:int(1, #sp - 1)
      s, e, col = sp[i].s, sp[i + 1].s, sp[i].s
    elseif kind == "de" then
      local cands = {}
      for i, w in ipairs(sp) do
        if #w.w >= 5 then
          cands[#cands + 1] = i
        end
      end
      if #cands == 0 then
        return nil
      end
      local w = sp[rng:pick(cands)]
      s = w.s + rng:int(1, #w.w - 3)
      e, col = w.e + 1, s
    elseif kind == "d$" then
      local i = rng:int(2, #sp)
      s, e, col = sp[i].s, #line, sp[i].s
    elseif kind == "d0" then
      local i = rng:int(2, #sp)
      s, e, col = 0, sp[i].s, sp[i].s
    elseif kind == "db" then
      local i = rng:int(2, #sp)
      s, e, col = sp[i - 1].s, sp[i].s, sp[i].s
    else -- d2w / d3w
      local k = rng:int(2, 3)
      local i = rng:int(1, #sp - k)
      s, e, col = sp[i].s, sp[i + k].s, sp[i].s
    end
    local goal = line:sub(1, s) .. line:sub(e + 1)
    col = U.maybe_wander(rng, ctx, col, line, 0.3)
    return {
      kind = "edit",
      lines = { line },
      cursor = { 1, col },
      goal_lines = { goal },
      prompt = "Delete the highlighted text",
    }
  end,
}
