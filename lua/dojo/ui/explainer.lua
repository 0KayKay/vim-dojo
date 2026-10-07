-- One screen per stage: keys, an example, a tip (SPEC.md §8 Explainer).
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local curriculum = require("dojo.curriculum")
local progress = require("dojo.progress")

local M = {}

local current
local mapped = false

local function map(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", function()
    progress.mark_explainer(current)
    require("dojo.session").start(current, "drill")
  end, o)
  for _, k in ipairs({ "q", "m" }) do
    vim.keymap.set("n", k, function()
      progress.mark_explainer(current)
      require("dojo.ui.menu").show(current)
    end, o)
  end
end

function M.show(id)
  current = id
  local st = curriculum.get(id)
  local ex = st.explainer
  local buf, win = layout.show("explainer")
  if not mapped then
    map(buf)
    mapped = true
  end
  local width = math.min(vim.api.nvim_win_get_width(win), 100)
  local rows = {
    { { string.format(" %s  %s  ·  %s", st.id, st.title, ex.heading), "DojoTitle" } },
    "",
  }
  local kw = 6
  for _, k in ipairs(ex.keys) do
    kw = math.max(kw, render.width(k[1]) + 2)
  end
  for _, k in ipairs(ex.keys) do
    rows[#rows + 1] = { { " " }, { render.fit(k[1], kw), "DojoKey" }, { k[2] } }
  end
  rows[#rows + 1] = ""
  rows[#rows + 1] = { { " Example", "DojoDim" } }
  local function block(label, lines)
    for i, l in ipairs(lines) do
      local segs = render.cursor_line(l, nil, "DojoTarget")
      table.insert(segs, 1, { i == 1 and string.format("   %-8s", label) or "           ", "DojoDim" })
      rows[#rows + 1] = segs
    end
  end
  block("before", ex.example.before)
  rows[#rows + 1] = { { "   type    ", "DojoDim" }, { ex.example.keys, "DojoKey" } }
  block("after", ex.example.after)
  rows[#rows + 1] = ""
  for i, l in ipairs(render.wrap(ex.tip, width - 8)) do
    rows[#rows + 1] = { { i == 1 and " Tip: " or "      ", "DojoDim" }, { l } }
  end
  rows[#rows + 1] = ""
  rows[#rows + 1] = { { " <CR> start the drill      q menu", "DojoDim" } }
  render.draw(buf, rows)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

return M
