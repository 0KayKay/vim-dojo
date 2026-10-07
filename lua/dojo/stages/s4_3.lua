local words = require("dojo.words")
local U = require("dojo.stages.util")

return {
  id = "4.3",
  title = "dt, ct)",
  name = "Operators meet find",
  kind = "edit",
  adds = {},
  focus = { { "d", "t" }, { "d", "f" }, { "c", "t" }, { "c", "f" } },
  explainer = {
    heading = "Operators meet find",
    keys = {
      { "dt{char}", "delete up to {char}, keep it" },
      { "df{char}", "delete up to and including {char}" },
      { "ct{char}", "change up to {char}" },
    },
    example = {
      before = { "print([h]ello there, world)" },
      keys = "dt,",
      after = { "print([,] world)" },
    },
    tip = "Read it out loud: delete till comma. That's dt,",
  },
  generate = function(rng, ctx)
    local L = words.code_line(rng)
    local sp = U.spans(L)
    for _ = 1, 60 do
      local p = rng:int(0, #L - 1)
      local ch = L:sub(p + 1, p + 1)
      local starts = {}
      for _, s in ipairs(sp) do
        if s.s <= p - 4 then
          starts[#starts + 1] = s.s
        end
      end
      if U.is_punct(ch) and #starts > 0 then
        local col = rng:pick(starts)
        if not L:sub(col + 2, p):find(ch, 1, true) then
          local kind = rng:pick({ "dt", "df", "ct" })
          local goal, prompt
          if kind == "dt" then
            goal = L:sub(1, col) .. L:sub(p + 1)
            prompt = "Delete the highlighted text"
          elseif kind == "df" then
            goal = L:sub(1, col) .. L:sub(p + 2)
            prompt = "Delete the highlighted text"
          else
            local new = words.pick(rng, 1, { avoid = { L:sub(col + 1, col + 1) }, max_len = 5 })[1]
            if new:sub(1, 1) == L:sub(col + 1, col + 1) then
              goto continue
            end
            goal = L:sub(1, col) .. new .. L:sub(p + 1)
            prompt = "Change the highlighted text to match the goal line"
          end
          return {
            kind = "edit",
            lines = { L },
            cursor = { 1, U.maybe_wander(rng, ctx, col, L, 0.25) },
            goal_lines = { goal },
            prompt = prompt,
          }
        end
      end
      ::continue::
    end
  end,
}
