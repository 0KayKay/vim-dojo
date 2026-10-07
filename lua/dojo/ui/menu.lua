-- Stage menu (SPEC.md §8 Menu).
local layout = require("dojo.ui.layout")
local render = require("dojo.ui.render")
local curriculum = require("dojo.curriculum")
local progress = require("dojo.progress")
local score = require("dojo.score")

local M = {}

local line_to_stage, stage_to_line = {}, {}
local mapped = false
local last_stage -- the stage last opened from here, to return the cursor to it

local function notify(msg)
  vim.api.nvim_echo({ { msg, "DojoWarn" } }, false, {})
end

local function selected()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  return line_to_stage[row]
end

local function step(dir)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local r = row + dir
  while r >= 1 and r <= vim.api.nvim_buf_line_count(0) do
    if line_to_stage[r] then
      vim.api.nvim_win_set_cursor(0, { r, 0 })
      return
    end
    r = r + dir
  end
end

-- explainer first, then the drill, then challenges
function M.continue(id)
  last_stage = id
  if not progress.unlocked(id) then
    notify(string.format("Stage %s is locked: earn a star in %s first.", id, curriculum.prev(id)))
    return
  end
  local st = progress.stage(id)
  if not st.explainer_seen then
    require("dojo.ui.explainer").show(id)
  elseif not st.drill_done then
    require("dojo.session").start(id, "drill")
  else
    require("dojo.session").start(id, "challenge")
  end
end

local function with_selected(fn)
  return function()
    local id = selected()
    if not id then
      return
    end
    if not progress.unlocked(id) then
      notify(string.format("Stage %s is locked: earn a star in %s first.", id, curriculum.prev(id)))
      return
    end
    last_stage = id
    fn(id)
  end
end

local function map(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", function()
    local id = selected()
    if id then
      M.continue(id)
    end
  end, o)
  vim.keymap.set("n", "d", with_selected(function(id)
    require("dojo.session").start(id, "drill")
  end), o)
  vim.keymap.set("n", "c", with_selected(function(id)
    if not progress.stage(id).drill_done then
      notify("Do the drill first; it starts now.")
      require("dojo.session").start(id, "drill")
    else
      require("dojo.session").start(id, "challenge")
    end
  end), o)
  vim.keymap.set("n", "?", with_selected(function(id)
    require("dojo.ui.explainer").show(id)
  end), o)
  vim.keymap.set("n", "H", function()
    progress.setting("habit", not progress.setting("habit"))
    M.show(selected())
  end, o)
  vim.keymap.set("n", "q", function()
    layout.close()
  end, o)
  for _, k in ipairs({ "j", "<Down>" }) do
    vim.keymap.set("n", k, function()
      step(1)
    end, o)
  end
  for _, k in ipairs({ "k", "<Up>" }) do
    vim.keymap.set("n", k, function()
      step(-1)
    end, o)
  end
  vim.keymap.set("n", "gg", function()
    vim.api.nvim_win_set_cursor(0, { stage_to_line[curriculum.order[1]], 0 })
  end, o)
  vim.keymap.set("n", "G", function()
    vim.api.nvim_win_set_cursor(0, { stage_to_line[curriculum.order[#curriculum.order]], 0 })
  end, o)
end

function M.remember(id)
  last_stage = id
end

-- the stage to put the cursor on: the first unlocked stage without a star
local function default_focus()
  local last
  for _, id in ipairs(curriculum.order) do
    if progress.unlocked(id) then
      last = id
      if progress.stage(id).best_stars == 0 then
        return id
      end
    end
  end
  return last
end

function M.show(focus)
  local buf, win = layout.show("menu")
  if not mapped then
    map(buf)
    mapped = true
  end
  local total, max = progress.total_stars()
  local habit = progress.setting("habit") and "on" or "off"
  local right = string.format("%d / %d ★   habit mode: %s ", total, max, habit)
  local width = vim.api.nvim_win_get_width(win)
  local rows = {
    { { " VIM DOJO", "DojoTitle" }, { string.rep(" ", math.max(1, width - 9 - render.width(right))) }, { right, "DojoDim" } },
    "",
  }
  line_to_stage, stage_to_line = {}, {}
  for w, world in ipairs(curriculum.worlds) do
    rows[#rows + 1] = { { string.format(" World %d · %s", w, world.name), "DojoWorld" } }
    for _, mod in ipairs(world.stages) do
      local st = require("dojo.stages." .. mod)
      local p = progress.stage(st.id)
      local status
      if not progress.unlocked(st.id) then
        status = { "locked", "DojoLocked" }
      elseif p.best_stars == 0 then
        status = { score.stars_text(0) .. "   new", "DojoStar" }
      else
        status = { score.stars_text(p.best_stars), "DojoStar" }
      end
      rows[#rows + 1] = {
        { "     " .. st.id .. "  " },
        { render.fit(st.title, 12), "DojoKey" },
        { render.fit(st.name, 22), "DojoDim" },
        status,
      }
      line_to_stage[#rows] = st.id
      stage_to_line[st.id] = #rows
    end
  end
  rows[#rows + 1] = ""
  rows[#rows + 1] = { { " <CR> play   d drill   c challenge   ? explainer   H habit mode   q quit", "DojoDim" } }
  render.draw(buf, rows)
  local id = focus or last_stage or default_focus()
  vim.api.nvim_win_set_cursor(win, { stage_to_line[id] or 3, 0 })
end

return M
