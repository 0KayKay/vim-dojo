-- One screen per stage: keys, an example, combinations, a tip. Bosses get the
-- world's "which move when" guide instead of an example (SPEC.md §8 Explainer).
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local curriculum = require("dojo.curriculum")
local progress = require("dojo.progress")

local M = {}

local current
local mapped -- the buffer that has our keymaps (it can be wiped and recreated)

local function start()
  progress.mark_explainer(current)
  local st = curriculum.get(current)
  require("dojo.session").start(current, st.is_boss and "boss" or "drill")
end

local function map(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", start, o)
  for _, k in ipairs({ "q", "m" }) do
    vim.keymap.set("n", k, function()
      progress.mark_explainer(current)
      require("dojo.ui.menu").show(current)
    end, o)
  end
end

-- rows of { key, text } pairs with the keys in a column
local function pairs_rows(rows, list, indent)
  local kw = 6
  for _, k in ipairs(list) do
    kw = math.max(kw, render.width(k[1]) + 2)
  end
  for _, k in ipairs(list) do
    rows[#rows + 1] = { { indent }, { render.fit(k[1], kw), "DojoKey" }, { k[2] } }
  end
end

function M.show(key)
  current = key
  local st = curriculum.get(key)
  local ex = st.explainer
  local status = st.is_boss and " <CR> start the boss   q menu" or " <CR> start the drill   q menu"
  local buf, win = layout.show("explainer", { status = status })
  if mapped ~= buf then
    map(buf)
    mapped = buf
  end
  local width = math.min(vim.api.nvim_win_get_width(win), 100)
  local rows = {
    { { string.format(" %s  %s  ·  %s", st.id, st.title, ex.heading), "DojoTitle" } },
    "",
  }
  pairs_rows(rows, ex.keys, " ")
  if ex.example then
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
  end
  if ex.combos and #ex.combos > 0 then
    rows[#rows + 1] = ""
    rows[#rows + 1] = { { " Combines with", "DojoDim" } }
    pairs_rows(rows, ex.combos, "   ")
  end
  if ex.guide and #ex.guide > 0 then
    rows[#rows + 1] = ""
    rows[#rows + 1] = { { " Which move when", "DojoDim" } }
    local lw = 0
    for _, g in ipairs(ex.guide) do
      lw = math.max(lw, render.width(g[1]) + 2)
    end
    for _, g in ipairs(ex.guide) do
      rows[#rows + 1] = { { "   " .. render.fit(g[1], lw) }, { g[2], "DojoKey" } }
    end
  end
  if ex.tip then
    rows[#rows + 1] = ""
    for i, l in ipairs(render.wrap(ex.tip, width - 8)) do
      rows[#rows + 1] = { { i == 1 and " Tip: " or "      ", "DojoDim" }, { l } }
    end
  end
  render.draw(buf, rows)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

return M
