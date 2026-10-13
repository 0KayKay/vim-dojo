-- How a round's goal is shown in the buffer (SPEC.md §5, decision 0016): the
-- target cell for move rounds; for edit rounds the change in place, text to
-- delete struck through and text to type as ghost text where it goes, both
-- aligned to words. No virtual lines, except for an insertion that spans
-- lines.
--
-- The ghost text is inline virtual text, which shifts screen columns, so j
-- and k land where they look straight up or down. The solver draws the same
-- marks in its scratch buffer, so par sees what the player sees.
local text = require("dojo.text")

local M = {}

function M.target(buf, ns, row, col)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, { end_col = col + 1, hl_group = "DojoTarget", priority = 200 })
end

-- lines: the buffer as it is now; goal_lines: what it should become
function M.edit(buf, ns, lines, goal_lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local from, to, typed = text.aligned_regions(lines, goal_lines)
  if not from.empty then
    vim.api.nvim_buf_set_extmark(buf, ns, from.srow - 1, from.scol, {
      end_row = from.erow - 1,
      end_col = from.ecol,
      hl_group = "DojoDelete",
      hl_eol = from.ecol == 0 and from.erow > from.srow,
      priority = 200,
    })
  end
  if to.empty then
    return
  end
  -- the ghost text goes after the struck text, so it reads old, then new
  local row, col = from.erow, from.ecol
  if from.ecol == 0 and from.erow > from.srow then
    row, col = from.erow - 1, #(lines[from.erow - 1] or "")
  end
  if not typed:find("\n", 1, true) then
    vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
      virt_text = { { typed, "DojoGoal" } },
      virt_text_pos = "inline",
      priority = 200,
    })
    return
  end
  -- new lines: show them as ghost lines under the change
  local virt = {}
  for _, l in ipairs(text.split(typed)) do
    virt[#virt + 1] = { { l, "DojoGoal" } }
  end
  vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, { virt_lines = virt })
end

return M
